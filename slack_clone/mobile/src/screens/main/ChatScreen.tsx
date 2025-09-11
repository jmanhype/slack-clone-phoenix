import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  SafeAreaView,
  RefreshControl,
  Alert,
  Animated,
  KeyboardAvoidingView,
  Platform,
  TextInput,
  Modal,
  TouchableOpacity,
} from 'react-native';
import { useTheme, useNavigation, useFocusEffect } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { MainStackParamList, Message } from '@types/index';
import { RootState, AppDispatch } from '@store/index';
import { 
  fetchMessages, 
  sendMessage,
  editMessage,
  updateTyping,
  markAsRead 
} from '@store/slices/chatSlice';
import MessageBubble from '@components/MessageBubble';
import MessageInput from '@components/MessageInput';
import { socketService } from '@services/socket';

type ChatScreenNavigationProp = NativeStackNavigationProp<MainStackParamList, 'Chat'>;

const ChatScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<ChatScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  
  const { 
    currentChannel, 
    messages, 
    isLoading,
    typing,
    presence 
  } = useSelector((state: RootState) => state.chat);
  const { user } = useSelector((state: RootState) => state.auth);
  
  const [refreshing, setRefreshing] = useState(false);
  const [replyingTo, setReplyingTo] = useState<Message | null>(null);
  const [editingMessage, setEditingMessage] = useState<Message | null>(null);
  const [editText, setEditText] = useState('');
  const [showEditModal, setShowEditModal] = useState(false);
  
  const flatListRef = useRef<FlatList>(null);
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const slideAnim = useRef(new Animated.Value(50)).current;

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

    if (currentChannel) {
      dispatch(fetchMessages(currentChannel.id));
      dispatch(markAsRead(currentChannel.id));
      
      // Join socket channel for real-time updates
      socketService.joinChannel(currentChannel.id);
    }

    return () => {
      if (currentChannel) {
        socketService.leaveChannel(currentChannel.id);
      }
    };
  }, [dispatch, currentChannel, fadeAnim, slideAnim]);

  useFocusEffect(
    useCallback(() => {
      if (currentChannel) {
        dispatch(markAsRead(currentChannel.id));
      }
    }, [dispatch, currentChannel])
  );

  const onRefresh = useCallback(async () => {
    if (!currentChannel) return;
    
    setRefreshing(true);
    try {
      await dispatch(fetchMessages(currentChannel.id)).unwrap();
    } catch (error) {
      Alert.alert('Error', 'Failed to refresh messages');
    } finally {
      setRefreshing(false);
    }
  }, [dispatch, currentChannel]);

  const handleSendMessage = useCallback(async (content: string, attachments?: any[]) => {
    if (!currentChannel) return;
    
    try {
      await dispatch(sendMessage({
        channelId: currentChannel.id,
        content,
        attachments,
        parentId: replyingTo?.id,
      })).unwrap();
      
      // Clear reply state
      setReplyingTo(null);
      
      // Scroll to bottom
      setTimeout(() => {
        flatListRef.current?.scrollToEnd({ animated: true });
      }, 100);
      
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to send message');
    }
  }, [currentChannel, dispatch, replyingTo]);

  const handleEditMessage = useCallback(async () => {
    if (!editingMessage || !editText.trim()) return;
    
    try {
      await dispatch(editMessage({
        messageId: editingMessage.id,
        content: editText.trim(),
      })).unwrap();
      
      setEditingMessage(null);
      setEditText('');
      setShowEditModal(false);
      
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to edit message');
    }
  }, [dispatch, editingMessage, editText]);

  const handleReply = useCallback((message: Message) => {
    setReplyingTo(message);
  }, []);

  const handleEdit = useCallback((message: Message) => {
    setEditingMessage(message);
    setEditText(message.content);
    setShowEditModal(true);
  }, []);

  const handleMessagePress = useCallback((message: Message) => {
    // TODO: Implement message thread navigation
    console.log('Message pressed:', message.id);
  }, []);

  const handleMessageLongPress = useCallback((message: Message) => {
    // This is handled in MessageBubble component
    console.log('Message long pressed:', message.id);
  }, []);

  const getTypingText = useCallback(() => {
    const typingUsers = Object.entries(typing)
      .filter(([userId, isTyping]) => isTyping && userId !== user?.id)
      .map(([userId]) => {
        // In a real app, you'd get user names from presence or user store
        return `User ${userId}`;
      });

    if (typingUsers.length === 0) return null;
    if (typingUsers.length === 1) return `${typingUsers[0]} is typing...`;
    if (typingUsers.length === 2) return `${typingUsers.join(' and ')} are typing...`;
    return `${typingUsers.length} people are typing...`;
  }, [typing, user]);

  const renderMessage = useCallback(({ item, index }: { item: Message; index: number }) => {
    const isOwn = item.user_id === user?.id;
    const previousMessage = index > 0 ? messages[index - 1] : undefined;
    const nextMessage = index < messages.length - 1 ? messages[index + 1] : undefined;
    
    return (
      <MessageBubble
        message={item}
        previousMessage={previousMessage}
        nextMessage={nextMessage}
        isOwn={isOwn}
        onReply={handleReply}
        onEdit={isOwn ? handleEdit : undefined}
        onPress={handleMessagePress}
        onLongPress={handleMessageLongPress}
      />
    );
  }, [messages, user, handleReply, handleEdit, handleMessagePress, handleMessageLongPress]);

  const renderTypingIndicator = () => {
    const typingText = getTypingText();
    if (!typingText) return null;

    return (
      <Animated.View 
        style={[
          styles.typingContainer,
          { backgroundColor: theme.colors.card }
        ]}
      >
        <View style={styles.typingBubble}>
          <View style={styles.typingDots}>
            <Animated.View style={[styles.typingDot, { backgroundColor: theme.colors.text }]} />
            <Animated.View style={[styles.typingDot, { backgroundColor: theme.colors.text }]} />
            <Animated.View style={[styles.typingDot, { backgroundColor: theme.colors.text }]} />
          </View>
        </View>
        <Text style={[styles.typingText, { color: theme.colors.text }]}>
          {typingText}
        </Text>
      </Animated.View>
    );
  };

  const renderReplyBanner = () => {
    if (!replyingTo) return null;

    return (
      <View style={[styles.replyBanner, { backgroundColor: theme.colors.card }]}>
        <Icon name="reply" size={16} color={theme.colors.primary} />
        <View style={styles.replyContent}>
          <Text style={[styles.replyUser, { color: theme.colors.primary }]}>
            Replying to {replyingTo.user?.name}
          </Text>
          <Text 
            style={[styles.replyMessage, { color: theme.colors.text }]}
            numberOfLines={1}
          >
            {replyingTo.content}
          </Text>
        </View>
        <TouchableOpacity 
          style={styles.replyClose}
          onPress={() => setReplyingTo(null)}
        >
          <Icon name="close" size={18} color={theme.colors.text} />
        </TouchableOpacity>
      </View>
    );
  };

  const renderEditModal = () => (
    <Modal
      visible={showEditModal}
      transparent
      animationType="slide"
      onRequestClose={() => setShowEditModal(false)}
    >
      <View style={styles.modalOverlay}>
        <KeyboardAvoidingView 
          style={styles.editModalContainer}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        >
          <View style={[styles.editModal, { backgroundColor: theme.colors.card }]}>
            <View style={styles.editModalHeader}>
              <Text style={[styles.editModalTitle, { color: theme.colors.text }]}>
                Edit Message
              </Text>
              <TouchableOpacity 
                onPress={() => setShowEditModal(false)}
                style={styles.editModalClose}
              >
                <Icon name="close" size={24} color={theme.colors.text} />
              </TouchableOpacity>
            </View>
            
            <TextInput
              style={[
                styles.editInput,
                { 
                  backgroundColor: theme.colors.background,
                  color: theme.colors.text,
                  borderColor: theme.colors.border,
                }
              ]}
              placeholder="Edit your message..."
              placeholderTextColor={theme.colors.text + '80'}
              value={editText}
              onChangeText={setEditText}
              multiline
              autoFocus
            />
            
            <View style={styles.editModalActions}>
              <TouchableOpacity
                style={[styles.editModalButton, { backgroundColor: theme.colors.border }]}
                onPress={() => setShowEditModal(false)}
              >
                <Text style={[styles.editModalButtonText, { color: theme.colors.text }]}>
                  Cancel
                </Text>
              </TouchableOpacity>
              
              <TouchableOpacity
                style={[styles.editModalButton, { backgroundColor: theme.colors.primary }]}
                onPress={handleEditMessage}
              >
                <Text style={[styles.editModalButtonText, { color: '#FFFFFF' }]}>
                  Save
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </View>
    </Modal>
  );

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: theme.colors.background,
    },
    header: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 16,
      paddingVertical: 12,
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    backButton: {
      padding: 8,
      marginRight: 8,
    },
    headerInfo: {
      flex: 1,
    },
    channelName: {
      fontSize: 18,
      fontWeight: '600',
      color: theme.colors.text,
    },
    channelMeta: {
      fontSize: 12,
      color: theme.colors.text,
      opacity: 0.7,
      marginTop: 2,
    },
    headerActions: {
      flexDirection: 'row',
    },
    headerButton: {
      padding: 8,
      marginLeft: 8,
    },
    messagesContainer: {
      flex: 1,
    },
    messagesList: {
      paddingVertical: 8,
    },
    typingContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 16,
      paddingVertical: 8,
      marginBottom: 8,
    },
    typingBubble: {
      backgroundColor: 'transparent',
      borderRadius: 18,
      paddingHorizontal: 12,
      paddingVertical: 8,
      marginRight: 8,
    },
    typingDots: {
      flexDirection: 'row',
    },
    typingDot: {
      width: 4,
      height: 4,
      borderRadius: 2,
      marginHorizontal: 1,
      opacity: 0.6,
    },
    typingText: {
      fontSize: 12,
      fontStyle: 'italic',
      opacity: 0.7,
    },
    replyBanner: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 16,
      paddingVertical: 8,
      borderTopWidth: 1,
      borderTopColor: theme.colors.border,
    },
    replyContent: {
      flex: 1,
      marginLeft: 8,
    },
    replyUser: {
      fontSize: 12,
      fontWeight: '500',
    },
    replyMessage: {
      fontSize: 12,
      opacity: 0.8,
      marginTop: 2,
    },
    replyClose: {
      padding: 4,
    },
    modalOverlay: {
      flex: 1,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      justifyContent: 'flex-end',
    },
    editModalContainer: {
      justifyContent: 'flex-end',
    },
    editModal: {
      borderTopLeftRadius: 20,
      borderTopRightRadius: 20,
      paddingBottom: Platform.OS === 'ios' ? 34 : 20,
    },
    editModalHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: 20,
      borderBottomWidth: 1,
      borderBottomColor: theme.colors.border,
    },
    editModalTitle: {
      fontSize: 18,
      fontWeight: '600',
    },
    editModalClose: {
      padding: 4,
    },
    editInput: {
      margin: 20,
      paddingHorizontal: 16,
      paddingVertical: 12,
      borderWidth: 1,
      borderRadius: 12,
      fontSize: 16,
      minHeight: 100,
      maxHeight: 200,
      textAlignVertical: 'top',
    },
    editModalActions: {
      flexDirection: 'row',
      paddingHorizontal: 20,
      gap: 12,
    },
    editModalButton: {
      flex: 1,
      paddingVertical: 12,
      borderRadius: 8,
      alignItems: 'center',
    },
    editModalButtonText: {
      fontSize: 16,
      fontWeight: '600',
    },
    loadingContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
    },
    emptyContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      paddingHorizontal: 40,
    },
    emptyText: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.7,
      textAlign: 'center',
      marginTop: 16,
    },
  });

  if (!currentChannel) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.emptyContainer}>
          <Icon name="forum" size={64} color={theme.colors.text + '40'} />
          <Text style={styles.emptyText}>
            No channel selected
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  const onlineCount = Object.values(presence).filter(p => p.online_at).length;

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity 
          style={styles.backButton}
          onPress={() => navigation.goBack()}
        >
          <Icon name="arrow-back" size={24} color={theme.colors.text} />
        </TouchableOpacity>
        
        <View style={styles.headerInfo}>
          <Text style={styles.channelName}>#{currentChannel.name}</Text>
          <Text style={styles.channelMeta}>
            {currentChannel.member_count || 0} members
            {onlineCount > 0 && ` • ${onlineCount} online`}
          </Text>
        </View>
        
        <View style={styles.headerActions}>
          <TouchableOpacity style={styles.headerButton}>
            <Icon name="call" size={20} color={theme.colors.text} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.headerButton}>
            <Icon name="videocam" size={20} color={theme.colors.text} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.headerButton}>
            <Icon name="more-vert" size={20} color={theme.colors.text} />
          </TouchableOpacity>
        </View>
      </View>

      {/* Messages */}
      <Animated.View 
        style={[
          styles.messagesContainer,
          {
            opacity: fadeAnim,
            transform: [{ translateY: slideAnim }],
          }
        ]}
      >
        <FlatList
          ref={flatListRef}
          style={styles.messagesList}
          data={messages}
          keyExtractor={(item) => item.id}
          renderItem={renderMessage}
          refreshControl={
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              tintColor={theme.colors.primary}
            />
          }
          showsVerticalScrollIndicator={false}
          maintainVisibleContentPosition={{
            minIndexForVisible: 0,
            autoscrollToTopThreshold: 100,
          }}
          ListFooterComponent={renderTypingIndicator}
        />
      </Animated.View>

      {/* Reply Banner */}
      {renderReplyBanner()}

      {/* Message Input */}
      <MessageInput
        placeholder={`Message #${currentChannel.name}`}
        onSend={handleSendMessage}
        disabled={isLoading}
      />

      {/* Edit Modal */}
      {renderEditModal()}
    </SafeAreaView>
  );
};

export default ChatScreen;