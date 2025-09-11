import React, { useState, useEffect, useCallback, useRef } from 'react';
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
  TextInput,
  Modal,
  Dimensions,
} from 'react-native';
import { useTheme, useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { MainStackParamList, Channel, ChannelType } from '@types/index';
import { RootState, AppDispatch } from '@store/index';
import { 
  fetchChannels, 
  joinChannel, 
  setCurrentChannel,
  updateTyping,
  updatePresence 
} from '@store/slices/chatSlice';

const { width, height } = Dimensions.get('window');

type ChannelListScreenNavigationProp = NativeStackNavigationProp<
  MainStackParamList,
  'ChannelList'
>;

const ChannelListScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<ChannelListScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  
  const { 
    currentWorkspace, 
    channels, 
    currentChannel,
    isLoading,
    presence 
  } = useSelector((state: RootState) => state.chat);
  
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newChannelName, setNewChannelName] = useState('');
  const [newChannelDescription, setNewChannelDescription] = useState('');
  const [newChannelType, setNewChannelType] = useState<ChannelType>('public');
  
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(30)).current;
  const searchInputRef = useRef<TextInput>(null);

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

    if (currentWorkspace) {
      dispatch(fetchChannels(currentWorkspace.id));
    }
  }, [dispatch, currentWorkspace, fadeAnim, slideAnim]);

  useFocusEffect(
    useCallback(() => {
      if (currentWorkspace) {
        dispatch(fetchChannels(currentWorkspace.id));
      }
    }, [dispatch, currentWorkspace])
  );

  const filteredChannels = channels.filter(channel =>
    channel.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (channel.description && channel.description.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  const onRefresh = useCallback(async () => {
    if (!currentWorkspace) return;
    
    setRefreshing(true);
    try {
      await dispatch(fetchChannels(currentWorkspace.id)).unwrap();
    } catch (error) {
      Alert.alert('Error', 'Failed to refresh channels');
    } finally {
      setRefreshing(false);
    }
  }, [dispatch, currentWorkspace]);

  const handleChannelSelect = useCallback(async (channel: Channel) => {
    try {
      await dispatch(setCurrentChannel(channel)).unwrap();
      navigation.navigate('Chat');
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to select channel');
    }
  }, [dispatch, navigation]);

  const handleJoinChannel = useCallback(async (channel: Channel) => {
    try {
      await dispatch(joinChannel(channel.id)).unwrap();
      await dispatch(setCurrentChannel(channel)).unwrap();
      navigation.navigate('Chat');
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to join channel');
    }
  }, [dispatch, navigation]);

  const handleCreateChannel = useCallback(async () => {
    if (!newChannelName.trim()) {
      Alert.alert('Error', 'Channel name is required');
      return;
    }

    try {
      // TODO: Implement channel creation API call
      Alert.alert('Coming Soon', 'Channel creation will be available in a future update.');
      setShowCreateModal(false);
      setNewChannelName('');
      setNewChannelDescription('');
      setNewChannelType('public');
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to create channel');
    }
  }, [newChannelName, newChannelDescription, newChannelType]);

  const getChannelIcon = (channel: Channel): string => {
    switch (channel.type) {
      case 'private':
        return 'lock';
      case 'direct':
        return 'person';
      default:
        return 'tag';
    }
  };

  const getUnreadCount = (channelId: string): number => {
    // TODO: Implement proper unread count logic
    return Math.floor(Math.random() * 5);
  };

  const getOnlineMembersCount = (channelId: string): number => {
    return Object.values(presence).filter(p => p.online_at).length;
  };

  const renderChannelItem = ({ item, index }: { item: Channel; index: number }) => {
    const unreadCount = getUnreadCount(item.id);
    const isCurrentChannel = currentChannel?.id === item.id;
    const onlineCount = getOnlineMembersCount(item.id);
    const itemScale = useRef(new Animated.Value(1)).current;

    const handlePressIn = () => {
      Animated.spring(itemScale, {
        toValue: 0.98,
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
          styles.channelItemContainer,
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
            styles.channelItem,
            {
              backgroundColor: isCurrentChannel ? theme.colors.primary + '10' : theme.colors.card,
              borderColor: isCurrentChannel ? theme.colors.primary : theme.colors.border,
            },
          ]}
          onPress={() => item.is_member ? handleChannelSelect(item) : handleJoinChannel(item)}
          onPressIn={handlePressIn}
          onPressOut={handlePressOut}
        >
          <View style={[
            styles.channelIcon,
            { backgroundColor: theme.colors.primary + '20' }
          ]}>
            <Icon 
              name={getChannelIcon(item)} 
              size={20} 
              color={theme.colors.primary} 
            />
          </View>
          
          <View style={styles.channelInfo}>
            <View style={styles.channelHeader}>
              <Text 
                style={[
                  styles.channelName, 
                  { color: theme.colors.text },
                  unreadCount > 0 && styles.channelNameUnread
                ]}
              >
                #{item.name}
              </Text>
              {!item.is_member && (
                <View style={[styles.joinBadge, { backgroundColor: theme.colors.primary }]}>
                  <Text style={styles.joinBadgeText}>Join</Text>
                </View>
              )}
            </View>
            
            {item.description && (
              <Text 
                style={[styles.channelDescription, { color: theme.colors.text }]}
                numberOfLines={1}
              >
                {item.description}
              </Text>
            )}
            
            <View style={styles.channelMeta}>
              <Icon 
                name="people" 
                size={12} 
                color={theme.colors.text + '80'} 
                style={styles.metaIcon}
              />
              <Text style={[styles.metaText, { color: theme.colors.text }]}>
                {item.member_count || 0}
              </Text>
              {onlineCount > 0 && (
                <>
                  <View style={[styles.onlineDot, { backgroundColor: '#00C851' }]} />
                  <Text style={[styles.metaText, { color: theme.colors.text }]}>
                    {onlineCount} online
                  </Text>
                </>
              )}
            </View>
          </View>
          
          <View style={styles.channelActions}>
            {unreadCount > 0 && (
              <View style={[styles.unreadBadge, { backgroundColor: theme.colors.primary }]}>
                <Text style={styles.unreadBadgeText}>
                  {unreadCount > 99 ? '99+' : unreadCount}
                </Text>
              </View>
            )}
            <Icon 
              name="chevron-right" 
              size={20} 
              color={theme.colors.text + '40'} 
            />
          </View>
        </TouchableOpacity>
      </Animated.View>
    );
  };

  const renderCreateChannelModal = () => (
    <Modal
      visible={showCreateModal}
      transparent
      animationType="slide"
      onRequestClose={() => setShowCreateModal(false)}
    >
      <View style={styles.modalOverlay}>
        <View style={[styles.modalContainer, { backgroundColor: theme.colors.card }]}>
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: theme.colors.text }]}>
              Create Channel
            </Text>
            <TouchableOpacity 
              onPress={() => setShowCreateModal(false)}
              style={styles.modalCloseButton}
            >
              <Icon name="close" size={24} color={theme.colors.text} />
            </TouchableOpacity>
          </View>
          
          <View style={styles.modalContent}>
            <View style={styles.inputGroup}>
              <Text style={[styles.inputLabel, { color: theme.colors.text }]}>
                Channel Name
              </Text>
              <TextInput
                style={[
                  styles.modalInput,
                  { 
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text,
                    borderColor: theme.colors.border,
                  }
                ]}
                placeholder="Enter channel name"
                placeholderTextColor={theme.colors.text + '80'}
                value={newChannelName}
                onChangeText={setNewChannelName}
                autoFocus
              />
            </View>
            
            <View style={styles.inputGroup}>
              <Text style={[styles.inputLabel, { color: theme.colors.text }]}>
                Description (Optional)
              </Text>
              <TextInput
                style={[
                  styles.modalInput,
                  { 
                    backgroundColor: theme.colors.background,
                    color: theme.colors.text,
                    borderColor: theme.colors.border,
                  }
                ]}
                placeholder="Enter channel description"
                placeholderTextColor={theme.colors.text + '80'}
                value={newChannelDescription}
                onChangeText={setNewChannelDescription}
                multiline
                numberOfLines={3}
              />
            </View>
            
            <View style={styles.inputGroup}>
              <Text style={[styles.inputLabel, { color: theme.colors.text }]}>
                Channel Type
              </Text>
              <View style={styles.typeSelector}>
                <TouchableOpacity
                  style={[
                    styles.typeOption,
                    { 
                      backgroundColor: newChannelType === 'public' 
                        ? theme.colors.primary + '20' 
                        : theme.colors.background,
                      borderColor: newChannelType === 'public' 
                        ? theme.colors.primary 
                        : theme.colors.border,
                    }
                  ]}
                  onPress={() => setNewChannelType('public')}
                >
                  <Icon name="tag" size={20} color={theme.colors.primary} />
                  <Text style={[styles.typeOptionText, { color: theme.colors.text }]}>
                    Public
                  </Text>
                </TouchableOpacity>
                
                <TouchableOpacity
                  style={[
                    styles.typeOption,
                    { 
                      backgroundColor: newChannelType === 'private' 
                        ? theme.colors.primary + '20' 
                        : theme.colors.background,
                      borderColor: newChannelType === 'private' 
                        ? theme.colors.primary 
                        : theme.colors.border,
                    }
                  ]}
                  onPress={() => setNewChannelType('private')}
                >
                  <Icon name="lock" size={20} color={theme.colors.primary} />
                  <Text style={[styles.typeOptionText, { color: theme.colors.text }]}>
                    Private
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          </View>
          
          <View style={styles.modalActions}>
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: theme.colors.border }]}
              onPress={() => setShowCreateModal(false)}
            >
              <Text style={[styles.modalButtonText, { color: theme.colors.text }]}>
                Cancel
              </Text>
            </TouchableOpacity>
            
            <TouchableOpacity
              style={[styles.modalButton, { backgroundColor: theme.colors.primary }]}
              onPress={handleCreateChannel}
            >
              <Text style={[styles.modalButtonText, { color: '#FFFFFF' }]}>
                Create
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: theme.colors.background,
    },
    header: {
      paddingHorizontal: 20,
      paddingTop: 16,
      paddingBottom: 8,
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    headerTop: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 16,
    },
    backButton: {
      padding: 8,
      marginRight: 8,
    },
    headerTitle: {
      flex: 1,
      fontSize: 20,
      fontWeight: 'bold',
      color: theme.colors.text,
    },
    workspaceName: {
      fontSize: 16,
      fontWeight: '600',
      color: theme.colors.text,
    },
    createButton: {
      padding: 8,
    },
    searchContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: theme.colors.card,
      borderRadius: 8,
      paddingHorizontal: 12,
      marginBottom: 8,
    },
    searchIcon: {
      marginRight: 8,
    },
    searchInput: {
      flex: 1,
      height: 40,
      fontSize: 16,
      color: theme.colors.text,
    },
    content: {
      flex: 1,
    },
    channelsList: {
      flex: 1,
      paddingHorizontal: 20,
      paddingTop: 8,
    },
    channelItemContainer: {
      marginBottom: 8,
    },
    channelItem: {
      flexDirection: 'row',
      alignItems: 'center',
      padding: 12,
      borderRadius: 8,
      borderWidth: 1,
    },
    channelIcon: {
      width: 36,
      height: 36,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      marginRight: 12,
    },
    channelInfo: {
      flex: 1,
    },
    channelHeader: {
      flexDirection: 'row',
      alignItems: 'center',
      marginBottom: 2,
    },
    channelName: {
      fontSize: 16,
      fontWeight: '500',
      flex: 1,
    },
    channelNameUnread: {
      fontWeight: '600',
    },
    joinBadge: {
      paddingHorizontal: 8,
      paddingVertical: 2,
      borderRadius: 10,
    },
    joinBadgeText: {
      color: '#FFFFFF',
      fontSize: 10,
      fontWeight: '600',
    },
    channelDescription: {
      fontSize: 13,
      opacity: 0.7,
      marginBottom: 4,
    },
    channelMeta: {
      flexDirection: 'row',
      alignItems: 'center',
    },
    metaIcon: {
      marginRight: 4,
    },
    metaText: {
      fontSize: 12,
      opacity: 0.8,
      marginRight: 12,
    },
    onlineDot: {
      width: 6,
      height: 6,
      borderRadius: 3,
      marginRight: 4,
    },
    channelActions: {
      alignItems: 'center',
    },
    unreadBadge: {
      minWidth: 20,
      height: 20,
      borderRadius: 10,
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 4,
    },
    unreadBadgeText: {
      color: '#FFFFFF',
      fontSize: 11,
      fontWeight: '600',
    },
    modalOverlay: {
      flex: 1,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      justifyContent: 'center',
      alignItems: 'center',
    },
    modalContainer: {
      width: width * 0.9,
      borderRadius: 12,
      overflow: 'hidden',
    },
    modalHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: 20,
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    modalTitle: {
      fontSize: 18,
      fontWeight: '600',
    },
    modalCloseButton: {
      padding: 4,
    },
    modalContent: {
      padding: 20,
    },
    inputGroup: {
      marginBottom: 20,
    },
    inputLabel: {
      fontSize: 14,
      fontWeight: '500',
      marginBottom: 8,
    },
    modalInput: {
      borderWidth: 1,
      borderRadius: 8,
      paddingHorizontal: 12,
      paddingVertical: 10,
      fontSize: 16,
    },
    typeSelector: {
      flexDirection: 'row',
      gap: 12,
    },
    typeOption: {
      flex: 1,
      flexDirection: 'row',
      alignItems: 'center',
      padding: 12,
      borderRadius: 8,
      borderWidth: 1,
    },
    typeOptionText: {
      marginLeft: 8,
      fontSize: 14,
      fontWeight: '500',
    },
    modalActions: {
      flexDirection: 'row',
      padding: 20,
      gap: 12,
    },
    modalButton: {
      flex: 1,
      paddingVertical: 12,
      borderRadius: 8,
      alignItems: 'center',
    },
    modalButtonText: {
      fontSize: 16,
      fontWeight: '600',
    },
  });

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <TouchableOpacity 
            style={styles.backButton}
            onPress={() => navigation.goBack()}
          >
            <Icon name="arrow-back" size={24} color={theme.colors.text} />
          </TouchableOpacity>
          
          <View style={{ flex: 1 }}>
            <Text style={styles.headerTitle}>Channels</Text>
            <Text style={styles.workspaceName}>{currentWorkspace?.name}</Text>
          </View>
          
          <TouchableOpacity 
            style={styles.createButton}
            onPress={() => setShowCreateModal(true)}
          >
            <Icon name="add" size={24} color={theme.colors.primary} />
          </TouchableOpacity>
        </View>
        
        <View style={styles.searchContainer}>
          <Icon 
            name="search" 
            size={20} 
            color={theme.colors.text + '80'} 
            style={styles.searchIcon}
          />
          <TextInput
            ref={searchInputRef}
            style={styles.searchInput}
            placeholder="Search channels..."
            placeholderTextColor={theme.colors.text + '80'}
            value={searchQuery}
            onChangeText={setSearchQuery}
          />
        </View>
      </View>
      
      <View style={styles.content}>
        <FlatList
          style={styles.channelsList}
          data={filteredChannels}
          keyExtractor={(item) => item.id}
          renderItem={renderChannelItem}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={theme.colors.primary}
            />
          }
          showsVerticalScrollIndicator={false}
        />
      </View>
      
      {renderCreateChannelModal()}
    </SafeAreaView>
  );
};

export default ChannelListScreen;