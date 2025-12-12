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
  Alert,
} from 'react-native';
import { supabase } from '@/lib/supabase';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';

interface EmailContact {
  id: string;
  name: string;
  email: string;
  company: string;
  lastContact: string;
}

export default function EmailListTab() {
  const [emailContacts, setEmailContacts] = useState<EmailContact[]>([]);
  const [savedEmails, setSavedEmails] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'all' | 'saved'>('all');

  useEffect(() => {
    fetchEmails();
    loadSavedEmails();
  }, []);

  const loadSavedEmails = async () => {
    try {
      const saved = await AsyncStorage.getItem('savedEmails');
      if (saved) {
        setSavedEmails(JSON.parse(saved));
      }
    } catch (err) {
      console.error('Error loading saved emails:', err);
    }
  };

  const fetchEmails = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.from('emails').select('*');

      if (error) throw error;

      if (data) {
        const uniqueEmails = new Map();
        data.forEach((email) => {
          if (!uniqueEmails.has(email.email)) {
            uniqueEmails.set(email.email, email);
          }
        });
        setEmailContacts(Array.from(uniqueEmails.values()));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch emails');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveEmail = async (id: string) => {
    const updated = [...savedEmails, id];
    setSavedEmails(updated);
    await AsyncStorage.setItem('savedEmails', JSON.stringify(updated));
  };

  const handleUnsaveEmail = async (id: string) => {
    const updated = savedEmails.filter((emailId) => emailId !== id);
    setSavedEmails(updated);
    await AsyncStorage.setItem('savedEmails', JSON.stringify(updated));
  };

  const handleSendEmail = (email: string) => {
    Linking.openURL(`mailto:${email}`);
  };

  const filteredEmails = emailContacts.filter((contact) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      contact.name.toLowerCase().includes(query) ||
      contact.email.toLowerCase().includes(query) ||
      contact.company?.toLowerCase().includes(query)
    );
  });

  const displayedEmails =
    activeTab === 'saved'
      ? filteredEmails.filter((email) => savedEmails.includes(email.id))
      : filteredEmails;

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
            All Emails
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
          placeholder="Search emails..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
      </View>

      <FlatList
        data={displayedEmails}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => {
          const isSaved = savedEmails.includes(item.id);
          return (
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>{item.name}</Text>
                <Ionicons name="mail-outline" size={20} color="#666" />
              </View>
              <Text style={styles.cardEmail}>{item.email}</Text>
              <Text style={styles.cardCompany}>Company: {item.company}</Text>
              <Text style={styles.cardDate}>
                Last contacted: {new Date(item.lastContact).toLocaleDateString()}
              </Text>
              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={styles.primaryButton}
                  onPress={() => handleSendEmail(item.email)}
                >
                  <Text style={styles.primaryButtonText}>Send Email</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.secondaryButton}
                  onPress={() =>
                    isSaved ? handleUnsaveEmail(item.id) : handleSaveEmail(item.id)
                  }
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
              {searchQuery ? 'No emails found matching your search.' : 'No emails found.'}
            </Text>
          </View>
        }
      />

      <TouchableOpacity
        style={styles.actionButton}
        onPress={() => Linking.openURL('https://n8n.socrani.com/form/6272f3aa-a2f6-417a-9977-2b11ec3488a7')}
      >
        <Text style={styles.actionButtonText}>Email Search</Text>
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
  cardEmail: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  cardCompany: {
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

