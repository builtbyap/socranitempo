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

interface LinkedInProfile {
  id: string;
  name: string;
  title: string;
  company: string;
  connections: number;
  linkedin: string;
}

export default function LinkedInProfilesTab() {
  const [profiles, setProfiles] = useState<LinkedInProfile[]>([]);
  const [savedProfiles, setSavedProfiles] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'all' | 'saved'>('all');

  useEffect(() => {
    fetchProfiles();
    loadSavedProfiles();
  }, []);

  const loadSavedProfiles = async () => {
    try {
      const saved = await AsyncStorage.getItem('savedLinkedInProfiles');
      if (saved) {
        setSavedProfiles(JSON.parse(saved));
      }
    } catch (err) {
      console.error('Error loading saved profiles:', err);
    }
  };

  const fetchProfiles = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.from('profiles').select('*');

      if (error) throw error;

      const validProfiles = (data || []).filter((profile) => profile && profile.id);
      setProfiles(validProfiles);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch profiles');
    } finally {
      setLoading(false);
    }
  };

  const handleSaveProfile = async (id: string) => {
    const updated = [...savedProfiles, id];
    setSavedProfiles(updated);
    await AsyncStorage.setItem('savedLinkedInProfiles', JSON.stringify(updated));
  };

  const handleUnsaveProfile = async (id: string) => {
    const updated = savedProfiles.filter((profileId) => profileId !== id);
    setSavedProfiles(updated);
    await AsyncStorage.setItem('savedLinkedInProfiles', JSON.stringify(updated));
  };

  const handleViewProfile = (url: string) => {
    if (url) {
      Linking.openURL(url);
    }
  };

  const filteredProfiles = profiles.filter((profile) => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    const fullName = profile.name || '';
    let displayName = fullName;
    if (fullName.includes(' - ')) {
      displayName = fullName.split(' - ')[0];
    }
    return (
      displayName.toLowerCase().includes(query) ||
      profile.title?.toLowerCase().includes(query) ||
      profile.company?.toLowerCase().includes(query)
    );
  });

  const displayedProfiles =
    activeTab === 'saved'
      ? filteredProfiles.filter((profile) => savedProfiles.includes(profile.id))
      : filteredProfiles;

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
            All Profiles
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
          placeholder="Search profiles..."
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
      </View>

      <FlatList
        data={displayedProfiles}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => {
          const isSaved = savedProfiles.includes(item.id);
          const fullName = item.name || 'No Name';
          let displayName = fullName;
          let titleFromName = '';

          if (fullName.includes(' - ')) {
            const parts = fullName.split(' - ');
            displayName = parts[0];
            titleFromName = parts.slice(1).join(' - ');
          }

          const displayTitle = titleFromName || item.title || 'No Title';

          return (
            <View style={styles.card}>
              <View style={styles.cardHeader}>
                <Text style={styles.cardTitle}>{displayName}</Text>
                <Ionicons name="logo-linkedin" size={20} color="#0077b5" />
              </View>
              <Text style={styles.cardDescription}>{displayTitle}</Text>
              <Text style={styles.cardCompany}>Company: {item.company || 'No Company'}</Text>
              <View style={styles.cardActions}>
                <TouchableOpacity
                  style={[styles.primaryButton, !item.linkedin && styles.disabledButton]}
                  onPress={() => handleViewProfile(item.linkedin || '')}
                  disabled={!item.linkedin}
                >
                  <Text style={styles.primaryButtonText}>
                    {item.linkedin ? 'View Profile' : 'No Link'}
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.secondaryButton}
                  onPress={() =>
                    isSaved ? handleUnsaveProfile(item.id) : handleSaveProfile(item.id)
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
              {searchQuery ? 'No profiles found matching your search.' : 'No profiles found.'}
            </Text>
          </View>
        }
      />

      <TouchableOpacity
        style={styles.actionButton}
        onPress={() => Linking.openURL('https://n8n.socrani.com/form/c85d7ad6-0b7b-436d-aad6-ee849404d145')}
      >
        <Text style={styles.actionButtonText}>LinkedIn Search</Text>
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
  cardCompany: {
    fontSize: 14,
    color: '#333',
    marginBottom: 12,
  },
  cardActions: {
    flexDirection: 'row',
    gap: 8,
  },
  primaryButton: {
    flex: 1,
    backgroundColor: '#0077b5',
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

