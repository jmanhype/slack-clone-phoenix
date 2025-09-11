import React, { useState, useRef, useCallback } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Animated,
  Alert,
  Platform,
  KeyboardAvoidingView,
  ActionSheetIOS,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { launchImageLibrary, launchCamera, ImagePickerResponse } from 'react-native-image-picker';
import AudioRecorderPlayer from 'react-native-audio-recorder-player';

import { RootState, AppDispatch } from '@store/index';
import { sendMessage, updateTyping } from '@store/slices/chatSlice';

interface MessageInputProps {
  placeholder?: string;
  onSend?: (message: string, attachments?: any[]) => void;
  disabled?: boolean;
}

const MessageInput: React.FC<MessageInputProps> = ({
  placeholder = "Type a message...",
  onSend,
  disabled = false,
}) => {
  const theme = useTheme();
  const dispatch = useDispatch<AppDispatch>();
  const { currentChannel, isTyping } = useSelector((state: RootState) => state.chat);
  
  const [message, setMessage] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [attachments, setAttachments] = useState<any[]>([]);
  const [recordTime, setRecordTime] = useState('00:00');
  
  const inputRef = useRef<TextInput>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const recordButtonScale = useRef(new Animated.Value(1)).current;
  const sendButtonScale = useRef(new Animated.Value(1)).current;
  const audioRecorderPlayer = useRef(new AudioRecorderPlayer()).current;

  const handleMessageChange = useCallback((text: string) => {
    setMessage(text);
    
    // Handle typing indicator
    if (currentChannel && text.length > 0) {
      dispatch(updateTyping({ channelId: currentChannel.id, isTyping: true }));
      
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
      
      typingTimeoutRef.current = setTimeout(() => {
        dispatch(updateTyping({ channelId: currentChannel.id, isTyping: false }));
      }, 2000);
    } else if (currentChannel) {
      dispatch(updateTyping({ channelId: currentChannel.id, isTyping: false }));
    }
  }, [currentChannel, dispatch]);

  const handleSend = useCallback(async () => {
    if (!message.trim() && attachments.length === 0) return;
    if (!currentChannel) return;

    const messageText = message.trim();
    
    try {
      await dispatch(sendMessage({
        channelId: currentChannel.id,
        content: messageText,
        attachments: attachments.length > 0 ? attachments : undefined,
      })).unwrap();

      setMessage('');
      setAttachments([]);
      
      // Stop typing indicator
      dispatch(updateTyping({ channelId: currentChannel.id, isTyping: false }));
      
      // Call custom onSend if provided
      onSend?.(messageText, attachments);
      
      // Animate send button
      Animated.sequence([
        Animated.timing(sendButtonScale, { toValue: 0.8, duration: 100, useNativeDriver: true }),
        Animated.timing(sendButtonScale, { toValue: 1, duration: 100, useNativeDriver: true }),
      ]).start();
      
    } catch (error: any) {
      Alert.alert('Error', error || 'Failed to send message');
    }
  }, [message, attachments, currentChannel, dispatch, onSend, sendButtonScale]);

  const showAttachmentOptions = useCallback(() => {
    const options = [
      'Camera',
      'Photo Library',
      'Cancel'
    ];
    
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          options,
          cancelButtonIndex: 2,
        },
        (buttonIndex) => {
          switch (buttonIndex) {
            case 0:
              openCamera();
              break;
            case 1:
              openImageLibrary();
              break;
          }
        }
      );
    } else {
      // For Android, you might want to use react-native-action-sheet or similar
      Alert.alert(
        'Select Attachment',
        'Choose an option',
        [
          { text: 'Camera', onPress: openCamera },
          { text: 'Photo Library', onPress: openImageLibrary },
          { text: 'Cancel', style: 'cancel' },
        ]
      );
    }
  }, []);

  const openCamera = useCallback(() => {
    launchCamera(
      {
        mediaType: 'mixed',
        quality: 0.8,
        maxWidth: 1920,
        maxHeight: 1080,
      },
      handleImageResponse
    );
  }, []);

  const openImageLibrary = useCallback(() => {
    launchImageLibrary(
      {
        mediaType: 'mixed',
        quality: 0.8,
        maxWidth: 1920,
        maxHeight: 1080,
        selectionLimit: 5,
      },
      handleImageResponse
    );
  }, []);

  const handleImageResponse = useCallback((response: ImagePickerResponse) => {
    if (response.didCancel || response.errorMessage) return;
    
    if (response.assets) {
      const newAttachments = response.assets.map(asset => ({
        uri: asset.uri,
        type: asset.type,
        name: asset.fileName || 'attachment',
        size: asset.fileSize,
      }));
      
      setAttachments(prev => [...prev, ...newAttachments]);
    }
  }, []);

  const removeAttachment = useCallback((index: number) => {
    setAttachments(prev => prev.filter((_, i) => i !== index));
  }, []);

  const startRecording = useCallback(async () => {
    try {
      const result = await audioRecorderPlayer.startRecorder();
      setIsRecording(true);
      setRecordTime('00:00');
      
      audioRecorderPlayer.addRecordBackListener((e) => {
        const minutes = Math.floor(e.currentPosition / 60000);
        const seconds = Math.floor((e.currentPosition % 60000) / 1000);
        setRecordTime(
          `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
        );
      });
      
      // Animate record button
      Animated.loop(
        Animated.sequence([
          Animated.timing(recordButtonScale, { toValue: 1.2, duration: 500, useNativeDriver: true }),
          Animated.timing(recordButtonScale, { toValue: 1, duration: 500, useNativeDriver: true }),
        ])
      ).start();
      
    } catch (error) {
      console.error('Failed to start recording:', error);
      Alert.alert('Error', 'Failed to start recording');
    }
  }, [audioRecorderPlayer, recordButtonScale]);

  const stopRecording = useCallback(async () => {
    try {
      const result = await audioRecorderPlayer.stopRecorder();
      setIsRecording(false);
      recordButtonScale.stopAnimation();
      recordButtonScale.setValue(1);
      
      // Add voice message to attachments
      if (result) {
        const voiceAttachment = {
          uri: result,
          type: 'audio/mpeg',
          name: `voice_message_${Date.now()}.mp3`,
          duration: recordTime,
        };
        
        setAttachments(prev => [...prev, voiceAttachment]);
      }
      
    } catch (error) {
      console.error('Failed to stop recording:', error);
      Alert.alert('Error', 'Failed to stop recording');
    }
  }, [audioRecorderPlayer, recordButtonScale, recordTime]);

  const handleRecordPress = useCallback(() => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }, [isRecording, startRecording, stopRecording]);

  const canSend = message.trim().length > 0 || attachments.length > 0;

  const styles = StyleSheet.create({
    container: {
      backgroundColor: theme.colors.background,
      borderTopWidth: 1,
      borderTopColor: theme.colors.border,
    },
    attachmentsContainer: {
      paddingHorizontal: 16,
      paddingTop: 8,
    },
    attachmentItem: {
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: theme.colors.card,
      paddingHorizontal: 12,
      paddingVertical: 8,
      borderRadius: 8,
      marginBottom: 4,
    },
    attachmentText: {
      flex: 1,
      fontSize: 14,
      color: theme.colors.text,
      marginLeft: 8,
    },
    removeAttachmentButton: {
      padding: 4,
    },
    inputContainer: {
      flexDirection: 'row',
      alignItems: 'flex-end',
      paddingHorizontal: 16,
      paddingVertical: 12,
      minHeight: 56,
    },
    attachButton: {
      width: 32,
      height: 32,
      borderRadius: 16,
      backgroundColor: theme.colors.card,
      justifyContent: 'center',
      alignItems: 'center',
      marginRight: 8,
    },
    inputWrapper: {
      flex: 1,
      backgroundColor: theme.colors.card,
      borderRadius: 20,
      paddingHorizontal: 16,
      paddingVertical: 8,
      maxHeight: 100,
      marginRight: 8,
    },
    input: {
      fontSize: 16,
      color: theme.colors.text,
      minHeight: 20,
    },
    recordingContainer: {
      flex: 1,
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: theme.colors.notification + '20',
      borderRadius: 20,
      paddingHorizontal: 16,
      paddingVertical: 12,
      marginRight: 8,
    },
    recordingText: {
      color: theme.colors.notification,
      fontSize: 16,
      fontWeight: '500',
      marginLeft: 8,
    },
    recordingTime: {
      color: theme.colors.text,
      fontSize: 14,
      marginLeft: 'auto',
    },
    actionButton: {
      width: 36,
      height: 36,
      borderRadius: 18,
      justifyContent: 'center',
      alignItems: 'center',
    },
    sendButton: {
      backgroundColor: theme.colors.primary,
    },
    sendButtonDisabled: {
      backgroundColor: theme.colors.border,
    },
    recordButton: {
      backgroundColor: theme.colors.notification,
    },
  });

  return (
    <KeyboardAvoidingView 
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      {/* Attachments Preview */}
      {attachments.length > 0 && (
        <View style={styles.attachmentsContainer}>
          {attachments.map((attachment, index) => (
            <View key={index} style={styles.attachmentItem}>
              <Icon 
                name={attachment.type?.startsWith('image') ? 'image' : 
                      attachment.type?.startsWith('audio') ? 'audiotrack' : 'attach-file'} 
                size={20} 
                color={theme.colors.primary} 
              />
              <Text style={styles.attachmentText}>
                {attachment.name}
                {attachment.duration && ` (${attachment.duration})`}
              </Text>
              <TouchableOpacity 
                style={styles.removeAttachmentButton}
                onPress={() => removeAttachment(index)}
              >
                <Icon name="close" size={16} color={theme.colors.text} />
              </TouchableOpacity>
            </View>
          ))}
        </View>
      )}

      {/* Input Container */}
      <View style={styles.inputContainer}>
        {/* Attachment Button */}
        <TouchableOpacity 
          style={styles.attachButton}
          onPress={showAttachmentOptions}
          disabled={disabled}
        >
          <Icon name="attach-file" size={20} color={theme.colors.text} />
        </TouchableOpacity>

        {/* Message Input or Recording Indicator */}
        {isRecording ? (
          <View style={styles.recordingContainer}>
            <Icon name="mic" size={20} color={theme.colors.notification} />
            <Text style={styles.recordingText}>Recording...</Text>
            <Text style={styles.recordingTime}>{recordTime}</Text>
          </View>
        ) : (
          <View style={styles.inputWrapper}>
            <TextInput
              ref={inputRef}
              style={styles.input}
              placeholder={placeholder}
              placeholderTextColor={theme.colors.text + '80'}
              value={message}
              onChangeText={handleMessageChange}
              multiline
              textAlignVertical="center"
              editable={!disabled}
            />
          </View>
        )}

        {/* Send/Record Button */}
        {canSend ? (
          <Animated.View style={{ transform: [{ scale: sendButtonScale }] }}>
            <TouchableOpacity 
              style={[styles.actionButton, styles.sendButton]}
              onPress={handleSend}
              disabled={disabled}
            >
              <Icon name="send" size={20} color="#FFFFFF" />
            </TouchableOpacity>
          </Animated.View>
        ) : (
          <Animated.View style={{ transform: [{ scale: recordButtonScale }] }}>
            <TouchableOpacity 
              style={[styles.actionButton, styles.recordButton]}
              onPress={handleRecordPress}
              disabled={disabled}
            >
              <Icon 
                name={isRecording ? "stop" : "mic"} 
                size={20} 
                color="#FFFFFF" 
              />
            </TouchableOpacity>
          </Animated.View>
        )}
      </View>
    </KeyboardAvoidingView>
  );
};

export default MessageInput;