import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  Alert,
  Animated,
  Dimensions,
} from 'react-native';
import { useTheme, useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { MainStackParamList, Workspace } from '@types/index';
import { RootState, AppDispatch } from '@store/index';
import { fetchWorkspaces, setCurrentWorkspace } from '@store/slices/chatSlice';
import { logout } from '@store/slices/authSlice';

const { width } = Dimensions.get('window');

type WorkspaceListScreenNavigationProp = NativeStackNavigationProp<
  MainStackParamList,
  'WorkspaceList'
>;

const WorkspaceListScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<WorkspaceListScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  
  const { workspaces, isLoading } = useSelector((state: RootState) => state.chat);
  const { user } = useSelector((state: RootState) => state.auth);
  
  const [refreshing, setRefreshing] = useState(false);
  const [selectedWorkspace, setSelectedWorkspace] = useState<string | null>(null);
  const fadeAnim = React.useRef(new Animated.Value(0)).current;
  const slideAnim = React.useRef(new Animated.Value(50)).current;

  useEffect(() => {
    // Animate screen entrance
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();

    // Load workspaces on mount
    dispatch(fetchWorkspaces());
  }, [dispatch, fadeAnim, slideAnim]);

  useFocusEffect(
    useCallback(() => {
      dispatch(fetchWorkspaces());
    }, [dispatch])
  );

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await dispatch(fetchWorkspaces()).unwrap();
    } catch (error) {
      Alert.alert('Error', 'Failed to refresh workspaces');
    } finally {
      setRefreshing(false);
    }
  }, [dispatch]);

  const handleWorkspaceSelect = useCallback(async (workspace: Workspace) => {
    setSelectedWorkspace(workspace.id);
    
    try {
      await dispatch(setCurrentWorkspace(workspace)).unwrap();
      navigation.navigate('ChannelList');
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to select workspace');
    } finally {
      setSelectedWorkspace(null);
    }
  }, [dispatch, navigation]);

  const handleLogout = useCallback(() => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Logout', 
          style: 'destructive',
          onPress: () => dispatch(logout())
        },
      ]
    );
  }, [dispatch]);

  const handleCreateWorkspace = useCallback(() => {
    // TODO: Implement workspace creation
    Alert.alert('Coming Soon', 'Workspace creation will be available in a future update.');
  }, []);

  const renderWorkspaceItem = ({ item, index }: { item: Workspace; index: number }) => {
    const isSelected = selectedWorkspace === item.id;
    const itemScale = React.useRef(new Animated.Value(1)).current;

    const handlePressIn = () => {
      Animated.spring(itemScale, {
        toValue: 0.95,
        useNativeDriver: true,
      }).start();
    };

    const handlePressOut = () => {
      Animated.spring(itemScale, {
        toValue: 1,
        useNativeDriver: true,
      }).start();
    };

    return (
      <Animated.View
        style={[
          styles.workspaceItemContainer,
          {
            transform: [
              { translateY: slideAnim },
              { scale: itemScale },
            ],
            opacity: fadeAnim,
          },
        ]}
      >
        <TouchableOpacity
          style={[
            styles.workspaceItem,
            {
              backgroundColor: theme.colors.card,
              borderColor: theme.colors.border,
            },
            isSelected && {
              backgroundColor: theme.colors.primary + '10',
              borderColor: theme.colors.primary,
            }
          ]}
          onPress={() => handleWorkspaceSelect(item)}
          onPressIn={handlePressIn}
          onPressOut={handlePressOut}
          disabled={isSelected}
        >
          <View style={styles.workspaceIcon}>
            <Text style={[styles.workspaceIconText, { color: theme.colors.primary }]}>
              {item.name.charAt(0).toUpperCase()}
            </Text>
          </View>
          
          <View style={styles.workspaceInfo}>
            <Text style={[styles.workspaceName, { color: theme.colors.text }]}>
              {item.name}
            </Text>
            <Text style={[styles.workspaceDescription, { color: theme.colors.text }]}>
              {item.description || 'No description'}
            </Text>
            <View style={styles.workspaceMeta}>
              <Icon 
                name="people" 
                size={14} 
                color={theme.colors.text + '80'} 
                style={styles.metaIcon}
              />
              <Text style={[styles.metaText, { color: theme.colors.text }]}>
                {item.member_count || 0} members
              </Text>
              <Icon 
                name="tag" 
                size={14} 
                color={theme.colors.text + '80'} 
                style={styles.metaIcon}
              />
              <Text style={[styles.metaText, { color: theme.colors.text }]}>
                {item.channel_count || 0} channels
              </Text>
            </View>
          </View>
          
          {isSelected ? (
            <View style={styles.loadingContainer}>
              <Icon name="hourglass-empty" size={24} color={theme.colors.primary} />
            </View>
          ) : (
            <Icon 
              name="chevron-right" 
              size={24} 
              color={theme.colors.text + '40'} 
            />
          )}
        </TouchableOpacity>
      </Animated.View>
    );
  };

  const renderEmptyState = () => (
    <Animated.View 
      style={[
        styles.emptyContainer,
        {
          opacity: fadeAnim,
          transform: [{ translateY: slideAnim }],
        }
      ]}
    >
      <Icon name="business" size={64} color={theme.colors.text + '40'} />
      <Text style={[styles.emptyTitle, { color: theme.colors.text }]}>
        No Workspaces
      </Text>
      <Text style={[styles.emptyDescription, { color: theme.colors.text }]}>
        You haven't joined any workspaces yet. Create or join one to get started.
      </Text>
      <TouchableOpacity
        style={[styles.createButton, { backgroundColor: theme.colors.primary }]}
        onPress={handleCreateWorkspace}
      >
        <Text style={styles.createButtonText}>Create Workspace</Text>
      </TouchableOpacity>
    </Animated.View>
  );

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: theme.colors.background,
    },
    header: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      paddingHorizontal: 20,
      paddingVertical: 16,
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    headerTitle: {
      fontSize: 24,
      fontWeight: 'bold',
      color: theme.colors.text,
    },
    userInfo: {
      flexDirection: 'row',
      alignItems: 'center',
    },
    userAvatar: {
      width: 32,
      height: 32,
      borderRadius: 16,
      backgroundColor: theme.colors.primary,
      justifyContent: 'center',
      alignItems: 'center',
      marginRight: 8,
    },
    userAvatarText: {
      color: '#FFFFFF',
      fontSize: 14,
      fontWeight: '600',
    },
    userName: {
      fontSize: 14,
      fontWeight: '500',
      color: theme.colors.text,
      marginRight: 12,
    },
    logoutButton: {
      padding: 8,
    },
    content: {
      flex: 1,
    },
    workspacesList: {
      flex: 1,
      paddingHorizontal: 20,
      paddingTop: 16,
    },
    workspaceItemContainer: {
      marginBottom: 12,
    },
    workspaceItem: {
      flexDirection: 'row',
      alignItems: 'center',
      padding: 16,
      borderRadius: 12,
      borderWidth: 1,
    },
    workspaceIcon: {
      width: 48,
      height: 48,
      borderRadius: 12,
      backgroundColor: theme.colors.primary + '20',
      justifyContent: 'center',
      alignItems: 'center',
      marginRight: 16,
    },
    workspaceIconText: {
      fontSize: 20,
      fontWeight: 'bold',
    },
    workspaceInfo: {
      flex: 1,
    },
    workspaceName: {
      fontSize: 18,
      fontWeight: '600',
      marginBottom: 4,
    },
    workspaceDescription: {
      fontSize: 14,
      opacity: 0.7,
      marginBottom: 8,
    },
    workspaceMeta: {
      flexDirection: 'row',
      alignItems: 'center',
    },
    metaIcon: {
      marginRight: 4,
      marginLeft: 12,
    },
    metaText: {
      fontSize: 12,
      opacity: 0.8,
    },
    loadingContainer: {
      padding: 8,
    },
    emptyContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      paddingHorizontal: 40,
    },
    emptyTitle: {
      fontSize: 20,
      fontWeight: '600',
      marginTop: 16,
      marginBottom: 8,
    },
    emptyDescription: {
      fontSize: 14,
      textAlign: 'center',
      opacity: 0.7,
      lineHeight: 20,
      marginBottom: 24,
    },
    createButton: {
      paddingHorizontal: 24,
      paddingVertical: 12,
      borderRadius: 8,
    },
    createButtonText: {
      color: '#FFFFFF',
      fontSize: 16,
      fontWeight: '600',
    },
  });

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Workspaces</Text>
        <View style={styles.userInfo}>
          <View style={styles.userAvatar}>
            <Text style={styles.userAvatarText}>
              {user?.name?.charAt(0).toUpperCase() || 'U'}
            </Text>
          </View>
          <Text style={styles.userName}>{user?.name}</Text>
          <TouchableOpacity style={styles.logoutButton} onPress={handleLogout}>
            <Icon name="logout" size={20} color={theme.colors.text} />
          </TouchableOpacity>
        </View>
      </View>
      
      <View style={styles.content}>
        <FlatList
          style={styles.workspacesList}
          data={workspaces}
          keyExtractor={(item) => item.id}
          renderItem={renderWorkspaceItem}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={theme.colors.primary}
            />
          }
          ListEmptyComponent={!isLoading ? renderEmptyState : null}
          showsVerticalScrollIndicator={false}
          contentContainerStyle={
            workspaces.length === 0 ? { flex: 1 } : undefined
          }
        />
      </View>
    </SafeAreaView>
  );
};

export default WorkspaceListScreen;