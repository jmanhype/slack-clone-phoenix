import React, { useState, useCallback, useRef } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Animated,
  Alert,
  Dimensions,
  Image,
  Linking,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { Swipeable } from 'react-native-gesture-handler';

import { Message, User } from '@types/index';
import { RootState, AppDispatch } from '@store/index';
import { 
  deleteMessage, 
  editMessage, 
  addReaction, 
  removeReaction 
} from '@store/slices/chatSlice';

const { width } = Dimensions.get('window');

interface MessageBubbleProps {
  message: Message;
  previousMessage?: Message;
  nextMessage?: Message;
  isOwn: boolean;
  showAvatar?: boolean;
  onReply?: (message: Message) => void;
  onEdit?: (message: Message) => void;
  onPress?: (message: Message) => void;
  onLongPress?: (message: Message) => void;
}

const MessageBubble: React.FC<MessageBubbleProps> = ({
  message,
  previousMessage,
  nextMessage,
  isOwn,
  showAvatar = true,
  onReply,
  onEdit,
  onPress,
  onLongPress,
}) => {
  const theme = useTheme();
  const dispatch = useDispatch<AppDispatch>();
  const { user } = useSelector((state: RootState) => state.auth);
  
  const [showReactions, setShowReactions] = useState(false);
  const scaleAnim = useRef(new Animated.Value(1)).current;
  const swipeableRef = useRef<Swipeable>(null);

  const isConsecutive = previousMessage?.user_id === message.user_id && 
    previousMessage && 
    (new Date(message.inserted_at).getTime() - new Date(previousMessage.inserted_at).getTime()) < 300000; // 5 minutes

  const formatTime = (timestamp: string): string => {
    const date = new Date(timestamp);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();
    
    if (isToday) {
      return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } else {
      return date.toLocaleDateString([], { month: 'short', day: 'numeric' }) + 
             ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
  };

  const handlePress = useCallback(() => {
    onPress?.(message);
  }, [message, onPress]);

  const handleLongPress = useCallback(() => {
    Animated.sequence([
      Animated.timing(scaleAnim, { toValue: 0.95, duration: 100, useNativeDriver: true }),
      Animated.timing(scaleAnim, { toValue: 1, duration: 100, useNativeDriver: true }),
    ]).start();
    
    onLongPress?.(message);
    
    // Show message actions
    showMessageActions();
  }, [message, onLongPress, scaleAnim]);

  const showMessageActions = useCallback(() => {
    const actions = [];
    
    if (onReply) actions.push({ text: 'Reply', onPress: () => onReply(message) });
    
    if (isOwn && onEdit) {
      actions.push({ text: 'Edit', onPress: () => onEdit(message) });
    }
    
    actions.push({ text: 'React', onPress: () => setShowReactions(true) });
    
    if (isOwn) {
      actions.push({ 
        text: 'Delete', 
        style: 'destructive' as const,
        onPress: () => handleDeleteMessage() 
      });
    }
    
    actions.push({ text: 'Cancel', style: 'cancel' as const });
    
    Alert.alert('Message Actions', undefined, actions);
  }, [message, isOwn, onReply, onEdit]);

  const handleDeleteMessage = useCallback(() => {
    Alert.alert(
      'Delete Message',
      'Are you sure you want to delete this message?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Delete', 
          style: 'destructive',
          onPress: () => dispatch(deleteMessage(message.id))
        },
      ]
    );
  }, [dispatch, message.id]);

  const handleReaction = useCallback((emoji: string) => {
    const existingReaction = message.reactions?.find(r => r.emoji === emoji);
    const userReacted = existingReaction?.users.some(u => u.id === user?.id);
    
    if (userReacted) {
      dispatch(removeReaction({ messageId: message.id, emoji }));
    } else {
      dispatch(addReaction({ messageId: message.id, emoji }));
    }
    
    setShowReactions(false);
  }, [message, user, dispatch]);

  const renderSwipeActions = () => (
    <View style={[styles.swipeActions, { backgroundColor: theme.colors.primary }]}>
      <Icon name="reply" size={24} color="#FFFFFF" />
    </View>
  );

  const handleSwipeAction = useCallback(() => {
    onReply?.(message);
    swipeableRef.current?.close();
  }, [message, onReply]);

  const renderAttachments = () => {
    if (!message.attachments || message.attachments.length === 0) return null;

    return (
      <View style={styles.attachmentsContainer}>
        {message.attachments.map((attachment, index) => (
          <View key={index} style={styles.attachmentItem}>
            {attachment.type?.startsWith('image/') ? (
              <Image 
                source={{ uri: attachment.url }} 
                style={styles.attachmentImage}
                resizeMode="cover"
              />
            ) : attachment.type?.startsWith('audio/') ? (
              <View style={[styles.audioAttachment, { backgroundColor: theme.colors.card }]}>
                <Icon name="audiotrack" size={20} color={theme.colors.primary} />
                <Text style={[styles.audioText, { color: theme.colors.text }]}>
                  Voice Message
                </Text>
                <TouchableOpacity>
                  <Icon name="play-arrow" size={24} color={theme.colors.primary} />
                </TouchableOpacity>
              </View>
            ) : (
              <TouchableOpacity 
                style={[styles.fileAttachment, { backgroundColor: theme.colors.card }]}
                onPress={() => Linking.openURL(attachment.url)}
              >
                <Icon name="attach-file" size={20} color={theme.colors.primary} />
                <Text style={[styles.fileName, { color: theme.colors.text }]}>
                  {attachment.name}
                </Text>
              </TouchableOpacity>
            )}
          </View>
        ))}
      </View>
    );
  };

  const renderReactions = () => {
    if (!message.reactions || message.reactions.length === 0) return null;

    return (
      <View style={styles.reactionsContainer}>
        {message.reactions.map((reaction, index) => {
          const userReacted = reaction.users.some(u => u.id === user?.id);
          
          return (
            <TouchableOpacity
              key={index}
              style={[
                styles.reactionBubble,
                {
                  backgroundColor: userReacted 
                    ? theme.colors.primary + '20' 
                    : theme.colors.card,
                  borderColor: userReacted 
                    ? theme.colors.primary 
                    : theme.colors.border,
                }
              ]}
              onPress={() => handleReaction(reaction.emoji)}
            >
              <Text style={styles.reactionEmoji}>{reaction.emoji}</Text>
              <Text style={[styles.reactionCount, { color: theme.colors.text }]}>
                {reaction.count}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    );
  };

  const renderReactionPicker = () => {
    if (!showReactions) return null;

    const commonReactions = ['👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '👏'];

    return (
      <View style={[styles.reactionPicker, { backgroundColor: theme.colors.card }]}>
        {commonReactions.map((emoji, index) => (
          <TouchableOpacity
            key={index}
            style={styles.reactionOption}
            onPress={() => handleReaction(emoji)}
          >
            <Text style={styles.reactionOptionEmoji}>{emoji}</Text>
          </TouchableOpacity>
        ))}
        <TouchableOpacity 
          style={styles.reactionClose}
          onPress={() => setShowReactions(false)}
        >
          <Icon name="close" size={20} color={theme.colors.text} />
        </TouchableOpacity>
      </View>
    );
  };

  const styles = StyleSheet.create({
    container: {
      marginVertical: isConsecutive ? 1 : 8,
      paddingHorizontal: 16,
    },
    messageRow: {
      flexDirection: isOwn ? 'row-reverse' : 'row',
      alignItems: 'flex-end',
    },
    avatar: {
      width: 32,
      height: 32,
      borderRadius: 16,
      backgroundColor: theme.colors.primary,
      justifyContent: 'center',
      alignItems: 'center',
      marginHorizontal: 8,
    },
    avatarPlaceholder: {
      width: 32,
      marginHorizontal: 8,
    },
    avatarText: {
      color: '#FFFFFF',
      fontSize: 12,
      fontWeight: '600',
    },
    messageContainer: {
      maxWidth: width * 0.75,
      marginHorizontal: 4,
    },
    messageHeader: {
      flexDirection: isOwn ? 'row-reverse' : 'row',
      alignItems: 'center',
      marginBottom: 4,
    },
    userName: {
      fontSize: 12,
      fontWeight: '600',
      color: theme.colors.text,
      opacity: 0.8,
      marginHorizontal: 8,
    },
    timestamp: {
      fontSize: 10,
      color: theme.colors.text,
      opacity: 0.6,
    },
    messageBubble: {
      backgroundColor: isOwn ? theme.colors.primary : theme.colors.card,
      borderRadius: 18,
      paddingHorizontal: 16,
      paddingVertical: 10,
      borderBottomRightRadius: isOwn ? 4 : 18,
      borderBottomLeftRadius: isOwn ? 18 : 4,
    },
    messageText: {
      fontSize: 16,
      color: isOwn ? '#FFFFFF' : theme.colors.text,
      lineHeight: 20,
    },
    editedIndicator: {
      fontSize: 11,
      color: isOwn ? '#FFFFFF' : theme.colors.text,
      opacity: 0.6,
      fontStyle: 'italic',
      marginTop: 2,
    },
    attachmentsContainer: {
      marginTop: 8,
    },
    attachmentItem: {
      marginBottom: 4,
    },
    attachmentImage: {
      width: '100%',
      height: 200,
      borderRadius: 12,
    },
    audioAttachment: {
      flexDirection: 'row',
      alignItems: 'center',
      padding: 12,
      borderRadius: 12,
    },
    audioText: {
      flex: 1,
      marginLeft: 8,
      fontSize: 14,
    },
    fileAttachment: {
      flexDirection: 'row',
      alignItems: 'center',
      padding: 12,
      borderRadius: 12,
    },
    fileName: {
      marginLeft: 8,
      fontSize: 14,
    },
    reactionsContainer: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      marginTop: 4,
      alignSelf: isOwn ? 'flex-end' : 'flex-start',
    },
    reactionBubble: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 8,
      paddingVertical: 4,
      borderRadius: 12,
      borderWidth: 1,
      marginRight: 4,
      marginBottom: 4,
    },
    reactionEmoji: {
      fontSize: 12,
      marginRight: 4,
    },
    reactionCount: {
      fontSize: 11,
      fontWeight: '500',
    },
    reactionPicker: {
      position: 'absolute',
      bottom: '100%',
      right: isOwn ? 0 : undefined,
      left: isOwn ? undefined : 0,
      flexDirection: 'row',
      alignItems: 'center',
      paddingHorizontal: 8,
      paddingVertical: 8,
      borderRadius: 24,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.25,
      shadowRadius: 4,
      elevation: 5,
      zIndex: 1000,
    },
    reactionOption: {
      padding: 8,
    },
    reactionOptionEmoji: {
      fontSize: 20,
    },
    reactionClose: {
      padding: 4,
      marginLeft: 8,
    },
    swipeActions: {
      flex: 1,
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      width: 80,
    },
    threadIndicator: {
      flexDirection: 'row',
      alignItems: 'center',
      marginTop: 4,
      paddingHorizontal: 8,
    },
    threadText: {
      fontSize: 12,
      color: theme.colors.primary,
      marginLeft: 4,
    },
  });

  return (
    <Animated.View 
      style={[
        styles.container,
        { transform: [{ scale: scaleAnim }] }
      ]}
    >
      {onReply ? (
        <Swipeable
          ref={swipeableRef}
          renderRightActions={!isOwn ? renderSwipeActions : undefined}
          renderLeftActions={isOwn ? renderSwipeActions : undefined}
          onSwipeableWillOpen={handleSwipeAction}
        >
          <TouchableOpacity
            onPress={handlePress}
            onLongPress={handleLongPress}
            delayLongPress={200}
          >
            <View style={styles.messageRow}>
              {!isOwn && (showAvatar && !isConsecutive) && (
                <View style={styles.avatar}>
                  <Text style={styles.avatarText}>
                    {message.user?.name?.charAt(0).toUpperCase() || 'U'}
                  </Text>
                </View>
              )}
              
              {!isOwn && (!showAvatar || isConsecutive) && (
                <View style={styles.avatarPlaceholder} />
              )}
              
              <View style={styles.messageContainer}>
                {!isConsecutive && (
                  <View style={styles.messageHeader}>
                    {!isOwn && (
                      <Text style={styles.userName}>
                        {message.user?.name || 'Unknown User'}
                      </Text>
                    )}
                    <Text style={styles.timestamp}>
                      {formatTime(message.inserted_at)}
                    </Text>
                  </View>
                )}
                
                <View style={styles.messageBubble}>
                  <Text style={styles.messageText}>{message.content}</Text>
                  {message.edited_at && (
                    <Text style={styles.editedIndicator}>(edited)</Text>
                  )}
                </View>
                
                {renderAttachments()}
                {renderReactions()}
                
                {message.thread_count && message.thread_count > 0 && (
                  <View style={styles.threadIndicator}>
                    <Icon name="forum" size={12} color={theme.colors.primary} />
                    <Text style={styles.threadText}>
                      {message.thread_count} {message.thread_count === 1 ? 'reply' : 'replies'}
                    </Text>
                  </View>
                )}
              </View>
              
              {isOwn && (showAvatar && !isConsecutive) && (
                <View style={styles.avatar}>
                  <Text style={styles.avatarText}>
                    {user?.name?.charAt(0).toUpperCase() || 'U'}
                  </Text>
                </View>
              )}
              
              {isOwn && (!showAvatar || isConsecutive) && (
                <View style={styles.avatarPlaceholder} />
              )}
            </View>
          </TouchableOpacity>
        </Swipeable>
      ) : (
        <TouchableOpacity
          onPress={handlePress}
          onLongPress={handleLongPress}
          delayLongPress={200}
        >
          <View style={styles.messageRow}>
            {/* Same content as above but without Swipeable wrapper */}
            {!isOwn && (showAvatar && !isConsecutive) && (
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>
                  {message.user?.name?.charAt(0).toUpperCase() || 'U'}
                </Text>
              </View>
            )}
            
            {!isOwn && (!showAvatar || isConsecutive) && (
              <View style={styles.avatarPlaceholder} />
            )}
            
            <View style={styles.messageContainer}>
              {!isConsecutive && (
                <View style={styles.messageHeader}>
                  {!isOwn && (
                    <Text style={styles.userName}>
                      {message.user?.name || 'Unknown User'}
                    </Text>
                  )}
                  <Text style={styles.timestamp}>
                    {formatTime(message.inserted_at)}
                  </Text>
                </View>
              )}
              
              <View style={styles.messageBubble}>
                <Text style={styles.messageText}>{message.content}</Text>
                {message.edited_at && (
                  <Text style={styles.editedIndicator}>(edited)</Text>
                )}
              </View>
              
              {renderAttachments()}
              {renderReactions()}
              
              {message.thread_count && message.thread_count > 0 && (
                <View style={styles.threadIndicator}>
                  <Icon name="forum" size={12} color={theme.colors.primary} />
                  <Text style={styles.threadText}>
                    {message.thread_count} {message.thread_count === 1 ? 'reply' : 'replies'}
                  </Text>
                </View>
              )}
            </View>
            
            {isOwn && (showAvatar && !isConsecutive) && (
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>
                  {user?.name?.charAt(0).toUpperCase() || 'U'}
                </Text>
              </View>
            )}
            
            {isOwn && (!showAvatar || isConsecutive) && (
              <View style={styles.avatarPlaceholder} />
            )}
          </View>
        </TouchableOpacity>
      )}
      
      {renderReactionPicker()}
    </Animated.View>
  );
};

export default MessageBubble;