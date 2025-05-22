export const metadata = {
  title: "Privacy Policy",
  description: "Privacy policy for Socrani",
};

export default function PrivacyPolicyPage() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <style jsx global>{`
        [data-custom-class='body'], [data-custom-class='body'] * {
          background: transparent !important;
        }
        [data-custom-class='title'], [data-custom-class='title'] * {
          font-family: Arial !important;
          font-size: 26px !important;
          color: #000000 !important;
        }
        [data-custom-class='subtitle'], [data-custom-class='subtitle'] * {
          font-family: Arial !important;
          color: #595959 !important;
          font-size: 14px !important;
        }
        [data-custom-class='heading_1'], [data-custom-class='heading_1'] * {
          font-family: Arial !important;
          font-size: 19px !important;
          color: #000000 !important;
        }
        [data-custom-class='heading_2'], [data-custom-class='heading_2'] * {
          font-family: Arial !important;
          font-size: 17px !important;
          color: #000000 !important;
        }
        [data-custom-class='body_text'], [data-custom-class='body_text'] * {
          color: #595959 !important;
          font-size: 14px !important;
          font-family: Arial !important;
        }
        [data-custom-class='link'], [data-custom-class='link'] * {
          color: #3030F1 !important;
          font-size: 14px !important;
          font-family: Arial !important;
          word-break: break-word !important;
        }
        ul {
          list-style-type: square;
        }
        ul > li > ul {
          list-style-type: circle;
        }
        ul > li > ul > li > ul {
          list-style-type: square;
        }
        ol li {
          font-family: Arial;
        }
      `}</style>
      {/* BEGIN PRIVACY POLICY HTML CONTENT */}
      <div data-custom-class="body">
        {/* Place your provided HTML content here, converted to JSX if needed. */}
        {/* For brevity, only a sample is shown. The full content should be pasted here. */}
        <div><strong><span style={{ fontSize: 26 }} data-custom-class="title"><h1>PRIVACY POLICY</h1></span></strong></div>
        <div><span style={{ color: '#7f7f7f' }}><strong><span style={{ fontSize: 15 }} data-custom-class="subtitle">Last updated May 22, 2025</span></strong></span></div>
        <div style={{ lineHeight: 1.5 }}>
          <span style={{ color: '#7f7f7f' }}>
            <span style={{ color: '#595959', fontSize: 15 }} data-custom-class="body_text">
              This Privacy Notice for <strong>Socrani</strong> ("we," "us," or "our"), describes how and why we might access, collect, store, use, and/or share ("process") your personal information when you use our services ("Services"), including when you:
            </span>
          </span>
        </div>
        <ul>
          <li data-custom-class="body_text" style={{ lineHeight: 1.5 }}>
            <span style={{ fontSize: 15, color: '#595959' }}>
              Visit our website at <a href="http://www.socrani.com" target="_blank" data-custom-class="link">http://www.socrani.com</a>, or any website of ours that links to this Privacy Notice
            </span>
          </li>
          <li data-custom-class="body_text" style={{ lineHeight: 1.5 }}>
            <span style={{ fontSize: 15, color: '#595959' }}>
              Download and use our mobile application (Socrani), or any other application of ours that links to this Privacy Notice
            </span>
          </li>
          <li data-custom-class="body_text" style={{ lineHeight: 1.5 }}>
            <span style={{ fontSize: 15, color: '#595959' }}>
              Engage with us in other related ways, including any sales, marketing, or events
            </span>
          </li>
        </ul>
        <div style={{ lineHeight: 1.5 }}>
          <span style={{ fontSize: 15, color: '#595959' }} data-custom-class="body_text">
            <strong>Questions or concerns? </strong>Reading this Privacy Notice will help you understand your privacy rights and choices. If you do not agree with our policies and practices, please do not use our Services. If you still have any questions or concerns, please contact us at thesocrani@gmail.com.
          </span>
        </div>
        {/* ... Continue with the rest of your privacy policy content ... */}
      </div>
      {/* END PRIVACY POLICY HTML CONTENT */}
    </div>
  );
} 