"""
JobSpy Service - FastAPI wrapper for JobSpy job scraping library
This service can be called from Deno Edge Functions to scrape jobs
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import pandas as pd
from jobspy import scrape_jobs
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="JobSpy Service", version="1.0.0")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class JobSpyRequest(BaseModel):
    """Request model for job scraping"""
    search_term: Optional[str] = None
    location: Optional[str] = None
    job_type: Optional[str] = None  # fulltime, parttime, internship, contract
    is_remote: Optional[bool] = False
    results_wanted: Optional[int] = 50
    hours_old: Optional[int] = None
    min_salary: Optional[int] = None  # in thousands (e.g., 100 = $100k)
    max_salary: Optional[int] = None  # in thousands (e.g., 150 = $150k)
    site_name: Optional[List[str]] = None  # ["indeed", "linkedin", "zip_recruiter", "glassdoor", "google"]
    country: Optional[str] = "usa"  # for Indeed/Glassdoor


class JobResponse(BaseModel):
    """Response model for a single job"""
    id: str
    title: str
    company: str
    location: str
    posted_date: str
    description: Optional[str] = None
    url: Optional[str] = None
    salary: Optional[str] = None
    job_type: Optional[str] = None
    site: Optional[str] = None


class JobSpyResponse(BaseModel):
    """Response model for job scraping"""
    success: bool
    jobs: List[JobResponse]
    count: int
    error: Optional[str] = None


def convert_jobspy_to_jobpost(row: pd.Series) -> JobResponse:
    """Convert JobSpy DataFrame row to JobPost format"""
    # Extract salary information
    salary_str = None
    if pd.notna(row.get('min_amount')) or pd.notna(row.get('max_amount')):
        min_amount = row.get('min_amount')
        max_amount = row.get('max_amount')
        interval = row.get('interval', 'yearly')
        
        # Convert to thousands if needed
        if interval == 'yearly':
            min_k = int(min_amount / 1000) if pd.notna(min_amount) else None
            max_k = int(max_amount / 1000) if pd.notna(max_amount) else None
        elif interval == 'monthly':
            min_k = int((min_amount * 12) / 1000) if pd.notna(min_amount) else None
            max_k = int((max_amount * 12) / 1000) if pd.notna(max_amount) else None
        elif interval == 'hourly':
            # Rough conversion: hourly * 2000 hours = annual
            min_k = int((min_amount * 2000) / 1000) if pd.notna(min_amount) else None
            max_k = int((max_amount * 2000) / 1000) if pd.notna(max_amount) else None
        else:
            min_k = int(min_amount / 1000) if pd.notna(min_amount) else None
            max_k = int(max_amount / 1000) if pd.notna(max_amount) else None
        
        # Format salary string
        if min_k and max_k:
            if min_k == max_k:
                salary_str = f"${min_k}k"
            else:
                salary_str = f"${min_k}k - ${max_k}k"
        elif min_k:
            salary_str = f"${min_k}k+"
        elif max_k:
            salary_str = f"Up to ${max_k}k"
    
    # Format location
    location_str = str(row.get('location', 'Location not specified'))
    if pd.isna(location_str) or location_str == 'nan':
        location_str = 'Location not specified'
    
    # Format job type
    job_type_str = None
    if pd.notna(row.get('job_type')):
        job_type_str = str(row.get('job_type'))
    
    # Format posted date
    posted_date = str(row.get('date_posted', ''))
    if pd.isna(posted_date) or posted_date == 'nan':
        from datetime import datetime
        posted_date = datetime.now().strftime('%Y-%m-%d')
    
    # Create unique ID
    job_id = f"jobspy_{row.get('site', 'unknown')}_{hash(str(row.get('job_url', '')) + str(row.get('title', '')))}"
    
    # Get description - ensure it's properly extracted
    description = None
    if pd.notna(row.get('description')):
        desc_text = str(row.get('description', ''))
        if desc_text and desc_text.strip() and desc_text.lower() not in ['nan', 'none', '']:
            description = desc_text.strip()
    
    return JobResponse(
        id=job_id,
        title=str(row.get('title', 'Job Title Not Available')),
        company=str(row.get('company', 'Company not specified')),
        location=location_str,
        posted_date=posted_date,
        description=description,  # Will be None if not available
        url=str(row.get('job_url', '')) if pd.notna(row.get('job_url')) else None,
        salary=salary_str,
        job_type=job_type_str,
        site=str(row.get('site', '')) if pd.notna(row.get('site')) else None
    )


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "service": "jobspy-service"}


@app.post("/scrape", response_model=JobSpyResponse)
async def scrape_jobs_endpoint(request: JobSpyRequest):
    """
    Scrape jobs using JobSpy based on user filtering parameters
    """
    try:
        logger.info(f"Received scrape request: {request.dict()}")
        
        # Map job_type to JobSpy format
        job_type_mapping = {
            "fulltime": "fulltime",
            "parttime": "parttime",
            "internship": "internship",
            "contract": "contract"
        }
        jobspy_job_type = job_type_mapping.get(request.job_type) if request.job_type else None
        
        # Determine which sites to scrape
        sites = request.site_name or ["indeed", "linkedin", "zip_recruiter", "glassdoor"]
        
        # Map country
        country_mapping = {
            "usa": "USA",
            "us": "USA",
            "united states": "USA",
            "canada": "Canada",
            "uk": "UK",
            "united kingdom": "UK",
            "australia": "Australia",
            "germany": "Germany",
            "france": "France",
        }
        country = country_mapping.get(request.country.lower() if request.country else "usa", "USA")
        
        logger.info(f"Scraping from sites: {sites}, job_type: {jobspy_job_type}, location: {request.location}")
        
        # Call JobSpy
        try:
            # Enable LinkedIn description fetching for full job details
            linkedin_fetch_description = 'linkedin' in sites
            
            jobs_df = scrape_jobs(
                site_name=sites,
                search_term=request.search_term,
                location=request.location,
                job_type=jobspy_job_type,
                is_remote=request.is_remote,
                results_wanted=request.results_wanted or 50,
                hours_old=request.hours_old,
                country_indeed=country,
                linkedin_fetch_description=linkedin_fetch_description,  # Fetch full descriptions for LinkedIn
                description_format="markdown",  # Use markdown format for better readability
                verbose=1  # Show some logs but not too verbose
            )
            
            logger.info(f"JobSpy returned {len(jobs_df)} jobs")
            
            if jobs_df.empty:
                return JobSpyResponse(
                    success=True,
                    jobs=[],
                    count=0
                )
            
            # Convert DataFrame to list of JobResponse
            jobs = []
            for _, row in jobs_df.iterrows():
                try:
                    job = convert_jobspy_to_jobpost(row)
                    jobs.append(job)
                except Exception as e:
                    logger.warning(f"Error converting job row: {e}")
                    continue
            
            # Apply salary filtering if specified
            if request.min_salary or request.max_salary:
                filtered_jobs = []
                for job in jobs:
                    if not job.salary or job.salary.lower() in ['salary not specified', 'none']:
                        continue  # Skip jobs without salary if user specified range
                    
                    # Extract salary range from job.salary (format: "$100k - $150k" or "$100k+")
                    import re
                    salary_match = re.findall(r'\$(\d+)k', job.salary)
                    if salary_match:
                        salary_values = [int(x) for x in salary_match]
                        job_min = min(salary_values)
                        job_max = max(salary_values) if len(salary_values) > 1 else salary_values[0]
                        
                        # Check if job salary overlaps with requested range
                        requested_min = request.min_salary or 0
                        requested_max = request.max_salary or float('inf')
                        
                        if job_max >= requested_min and job_min <= requested_max:
                            filtered_jobs.append(job)
                    else:
                        # If we can't parse salary, skip it
                        continue
                
                jobs = filtered_jobs
                logger.info(f"After salary filtering: {len(jobs)} jobs")
            
            return JobSpyResponse(
                success=True,
                jobs=jobs,
                count=len(jobs)
            )
            
        except Exception as e:
            logger.error(f"JobSpy scraping error: {e}", exc_info=True)
            return JobSpyResponse(
                success=False,
                jobs=[],
                count=0,
                error=f"JobSpy scraping failed: {str(e)}"
            )
            
    except Exception as e:
        logger.error(f"Service error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/scrape", response_model=JobSpyResponse)
async def scrape_jobs_get(
    search_term: Optional[str] = Query(None),
    location: Optional[str] = Query(None),
    job_type: Optional[str] = Query(None),
    is_remote: Optional[bool] = Query(False),
    results_wanted: Optional[int] = Query(50),
    hours_old: Optional[int] = Query(None),
    min_salary: Optional[int] = Query(None),
    max_salary: Optional[int] = Query(None),
    site_name: Optional[str] = Query(None),  # Comma-separated list
    country: Optional[str] = Query("usa")
):
    """GET endpoint for job scraping (convenience)"""
    sites = site_name.split(",") if site_name else None
    
    request = JobSpyRequest(
        search_term=search_term,
        location=location,
        job_type=job_type,
        is_remote=is_remote,
        results_wanted=results_wanted,
        hours_old=hours_old,
        min_salary=min_salary,
        max_salary=max_salary,
        site_name=sites,
        country=country
    )
    
    return await scrape_jobs_endpoint(request)


if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

