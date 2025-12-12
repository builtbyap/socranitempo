import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  Linking,
} from 'react-native';
import { supabase } from '@/lib/supabase';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';

interface JobPost {
  id: string;
  title: string;
  company: string;
  location: string;
  posted_date: string;
  description?: string;
  url?: string;
  salary?: string;
  job_type?: string;
}

export default function JobsPostsTab() {
  const [jobPosts, setJobPosts] = useState<JobPost[]>([]);
  const [savedPosts, setSavedPosts] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'all' | 'saved'>('all');

  useEffect(() => {
    fetchJobPosts();
    loadSavedPosts();
  }, []);

  const loadSavedPosts = async () => {
    try {
      const saved = await AsyncStorage.getItem('savedJobPosts');
      if (saved) {
        setSavedPosts(JSON.parse(saved));
      }
    } catch (err) {
      console.error('Error loading saved posts:', err);
    }
  };

  const fetchJobPosts = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('job_posts')
        .select('*')
        .order('posted_date', { ascending: false });

      if (error) throw error;

      if (data) {
        setJobPosts(data);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch job posts');
    } finally {
      setLoading(false);
    }
  };

  const handleSavePost = async (id: string) => {
    const updated = [...savedPosts, id];
    setSavedPosts(updated);
    await AsyncStorage.setItem('savedJobPosts', JSON.stringify(updated));
  };

  const handleUnsavePost = async (id: string) => {
    const updated = savedPosts.filter((postId) => postId !== id);
    setSavedPosts(updated);
    await AsyncStorage.setItem('savedJobPosts', JSON.stringify(updated));
  };

  const handleViewDetails = (url?: string) => {
    if (url) {
      Linking.openURL(url);
    }
  };

  const filteredPosts = jobPosts.filter((post) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      post.title.toLowerCase().includes(query) ||
      post.company.toLowerCase().includes(query) ||
      post.location?.toLowerCase().includes(query) ||
      post.description?.toLowerCase().includes(query)
    );
  });

  const displayedPosts =
    activeTab === 'saved'
      ? filteredPosts.filter((post) => savedPosts.includes(post.id))
      : filteredPosts;

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#000" />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>Error: {error}</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.tabBar}>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'all' && styles.activeTab]}
          onPress={() => setActiveTab('all')}
        >
          <Text style={[styles.tabText, activeTab === 'all' && styles.activeTabText]}>
            All Jobs
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.tab, activeTab === 'saved' && styles.activeTab]}
          onPress={() => setActiveTab('saved')}
        >
          <Text style={[styles.tabText, activeTab === 'saved' && styles.activeTabText]}>
            Saved
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.searchContainer}>
        <Ionicons name="search" size={20} color="#666" style={styles.searchIcon} />
        <TextInput
          style={styles.searchInput}
          placeholder="Search jobs..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
      </View>

      <FlatList
        data={displayedPosts}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => {
          const isSaved = savedPosts.includes(item.id);
          return (
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>{item.title}</Text>
                <Ionicons name="briefcase-outline" size={20} color="#666" />
              </View>
              <Text style={styles.cardDescription}>{item.company}</Text>
              <Text style={styles.cardInfo}>Location: {item.location || 'Not specified'}</Text>
              {item.salary && (
                <Text style={styles.cardInfo}>Salary: {item.salary}</Text>
              )}
              {item.job_type && (
                <Text style={styles.cardInfo}>Type: {item.job_type}</Text>
              )}
              <Text style={styles.cardDate}>
                Posted: {new Date(item.posted_date).toLocaleDateString()}
              </Text>
              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={[styles.primaryButton, !item.url && styles.disabledButton]}
                  onPress={() => handleViewDetails(item.url)}
                  disabled={!item.url}
                >
                  <Text style={styles.primaryButtonText}>
                    {item.url ? 'View Details' : 'No Link'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.secondaryButton}
                  onPress={() => (isSaved ? handleUnsavePost(item.id) : handleSavePost(item.id))}
                >
                  <Ionicons
                    name={isSaved ? 'star' : 'star-outline'}
                    size={20}
                    color={isSaved ? '#fbbf24' : '#666'}
                  />
                </TouchableOpacity>
              </View>
            </View>
          );
        }}
        contentContainerStyle={styles.list}
        ListEmptyComponent={
          <View style={styles.center}>
            <Text style={styles.emptyText}>
              {searchQuery ? 'No jobs found matching your search.' : 'No job posts found.'}
            </Text>
          </View>
        }
      />

      <TouchableOpacity
        style={styles.actionButton}
        onPress={() => Linking.openURL('https://n8n.socrani.com/form/job-search-form')}
      >
        <Text style={styles.actionButtonText}>Job Search</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  tab: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    marginHorizontal: 4,
    alignItems: 'center',
  },
  activeTab: {
    backgroundColor: '#000',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#666',
  },
  activeTabText: {
    color: '#fff',
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    margin: 16,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  searchIcon: {
    marginRight: 8,
  },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: 16,
  },
  list: {
    padding: 16,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    flex: 1,
  },
  cardDescription: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  cardInfo: {
    fontSize: 14,
    color: '#333',
    marginBottom: 4,
  },
  cardDate: {
    fontSize: 12,
    color: '#999',
    marginBottom: 12,
  },
  cardActions: {
    flexDirection: 'row',
    gap: 8,
  },
  primaryButton: {
    flex: 1,
    backgroundColor: '#000',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  disabledButton: {
    backgroundColor: '#ccc',
  },
  primaryButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
  secondaryButton: {
    padding: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  error: {
    color: '#ef4444',
    fontSize: 14,
  },
  emptyText: {
    color: '#666',
    fontSize: 14,
    textAlign: 'center',
  },
  actionButton: {
    backgroundColor: '#000',
    margin: 16,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

