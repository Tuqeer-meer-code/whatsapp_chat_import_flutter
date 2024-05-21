import 'dart:io';

import 'package:whatsapp_android_pluging/models/languages.dart';
import 'package:whatsapp_android_pluging/models/msg_content.dart';
import 'package:whatsapp_android_pluging/utils/fix_dates_utils.dart';

import '../../models/chat_content.dart';

class ChatInfoUtilities {
  /// [_regExp] to find where each message starts and Where it ends:
  /// Android:
  /// message starts with somthing like: "25/04/2022, 10:17 - Dolev Test Phone: Hi"
  /// iOS:
  /// message starts with somthing like: "[25/04/2022, 10:17:07] Dolev Test Phone: Hi"
  // static final RegExp _regExp = RegExp(r"[?\d\d?[/|.]\d\d?[/|.]\d?\d?\d\d,?\s\d\d?:\d\d:?\d?\d?\s?-?]?\s?");
  static final RegExp _regExp = RegExp(r"[\[?\d\d?[/|.]\d\d?[/|.]\d?\d?\d\d,?\s\d\d?:\d\d:?\d?\d?\s?-?]?\s?");
  static final RegExp _regExpIOS = RegExp(r"\[.*?\] (.*)");

  /// [_regExpToSplitLineAndroid] and [_regExpToSplitLineIOS] to get the message date and time
  static final RegExp _regExpToSplitLineAndroid = RegExp(r"\s-\s");
  // static final RegExp _regExpToSplitLineIOS = RegExp(r":\d\d]\s");
  static final RegExp _regExpToSplitLineIOS = RegExp(r"[\]]\s");

  /// chat info contains messages per member, members of the chat, messages, and size of the chat
  static ChatContent getChatInfo(List<String> chat) {
    bool isAndroid = Platform.isAndroid;
    List<String> names = [];
    List<List<int>> countNameMsgs = [];
    List<MessageContent> msgContents = [];
    List<String> lines = [];
    bool first = true;
    RegExp regExp = isAndroid ? _regExp : _regExpIOS;

    for (int i = isAndroid ? 1 : 2; i < chat.length; i++) {
      if (regExp.hasMatch(chat[i])) {
        lines.add(chat[i]);
        if (!first) {
          MessageContent msgContent = _getMsgContentFromStringLine(lines[lines.length - (isAndroid ? 1 : 2)]);
          if (!names.contains(msgContent.senderId) && msgContent.senderId != null) {
            names.add(msgContent.senderId!);
            countNameMsgs.add([msgContents.length]);
            msgContents.add(msgContent);
          } else {
            if (msgContent.senderId != null) {
              countNameMsgs[names.indexOf(msgContent.senderId!)].add(msgContents.length);
              msgContents.add(msgContent);
            }
          }
        }
        first = false;
      } else {
        try {
          lines[lines.length - 1] += "\n" + chat[i];
        } catch (e, s) {
          print("${e.toString()}  Stack is $s");
        }
      }
    }

    names.remove(null);
    Map<String, List<int>> indexesPerMember = {};
    Map<String, int> msgsPerPerson = {};

    names.remove(null);
    for (int i = 0; i < names.length; i++) {
      msgsPerPerson[names[i]] = countNameMsgs[i].length;
      indexesPerMember[names[i]] = countNameMsgs[i];
    }

    return ChatContent(
      members: names,
      messages: msgContents,
      sizeOfChat: msgContents.length,
      indexesPerMember: indexesPerMember,
      msgsPerMember: msgsPerPerson,
      chatName: '',
    );
  }

  /// Receive a String line and return from it [MessageContent]
  static MessageContent _getMsgContentFromStringLine(String line) {
    MessageContent nullMessageContent = MessageContent(senderId: null, msg: null);

    if (Platform.isAndroid && line.split(_regExpToSplitLineAndroid).length == 1) {
      return nullMessageContent;
    } else if (Platform.isIOS && line.split(_regExpToSplitLineIOS).length == 1) {
      return nullMessageContent;
    }
    RegExp regExp = Platform.isAndroid ? _regExp : _regExpIOS;

    String splitLineToTwo = Platform.isAndroid ? line.split(regExp).last : line.split('] ').last;
    if (splitLineToTwo.split(': ').length == 1) {
      return nullMessageContent;
    }

    String senderId = splitLineToTwo.split(': ')[0];
    String msg = splitLineToTwo.split(': ').sublist(1).join(': ');

    if (Languages.hasMatchForAll(msg)) {
      return nullMessageContent;
    }

    return MessageContent(
      senderId: senderId,
      msg: msg,
      dateTime: _parseLineToDatetime(line),
    );
  }

  /// Receive a String line and return from it [DateTime], if it fails it returns null
  static DateTime? _parseLineToDatetime(String line) {
    RegExp regExp;
    if (Platform.isAndroid) {
      regExp = _regExpToSplitLineAndroid;
    } else if (Platform.isIOS) {
      regExp = _regExpToSplitLineIOS;
    } else {
      return null;
    }
    if (line.split(regExp).length == 1) {
      return null;
    }

    String splitLineToTwo = line.split(regExp).first;

    List dateFromLine = splitLineToTwo.split(RegExp(r",?\s"));

    if (dateFromLine.length == 1) {
      return null;
    }

    String? date;
    String? hour;
    try {
      date = FixDateUtilities.dateStringOrganization(dateFromLine[0]);
      hour = FixDateUtilities.hourStringOrganization(dateFromLine[1], dateFromLine[2]);
    } catch (e) {
      return null;
    }
    DateTime datetime;
    try {
      datetime = DateTime.parse(
        '$date $hour',
      );
    } catch (e) {
      return null;
    }

    return datetime;
  }
}
