import 'dart:io';

import 'package:whatsapp_android_pluging/models/chat_content.dart';
import 'package:whatsapp_android_pluging/utils/chat_info_utils.dart';

class ChatAnalyzer {
  /// Analyze [List<String>] to [ChatContent]
  static ChatContent analyze(List<String> chat, [List<String>? imagePaths]) {
    String chatName = _getChatName(chat.first);
    ChatContent chatInfo = ChatInfoUtilities.getChatInfo(chat);

    return ChatContent(
      members: chatInfo.members,
      messages: chatInfo.messages,
      sizeOfChat: chatInfo.sizeOfChat,
      indexesPerMember: chatInfo.indexesPerMember,
      msgsPerMember: chatInfo.msgsPerMember,
      imagesPaths: imagePaths,
      chatName: chatName,
    );
  }

  /// In case your phone is one English, The name of the chat will be like this:
  /// WhatsApp Chat with [name_of_chat].txt
  /// The function spilt the name of the chat.
  static String _getChatName(String name) {
    if (Platform.isAndroid) {
      return name.split('.zip').first.split('WhatsApp Chat with ').last;
    } else {
      return name.split('.zip').first.split('WhatsApp Chat - ').last;
    }
  }
}
