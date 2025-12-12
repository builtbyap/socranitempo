import { useEffect } from 'react';
import { router } from 'expo-router';
import { supabase } from '@/lib/supabase';
import { View, ActivityIndicator, StyleSheet } from 'react-native';

export default function Index() {
  useEffect(() => {
    checkSession();
  }, []);

  const checkSession = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (session) {
      router.replace('/(tabs)/dashboard');
    } else {
      router.replace('/(auth)/sign-in');
    }
  };

  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color="#000" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});

