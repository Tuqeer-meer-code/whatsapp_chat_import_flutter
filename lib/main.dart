import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:whatsapp_android_pluging/chat_analyzer.dart';
import 'package:whatsapp_android_pluging/data_handle.dart';
import 'package:whatsapp_android_pluging/models/chat_content.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:whatsapp_android_pluging/models/msg_content.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsappImport',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late StreamSubscription _intentSub;
  var pdfFile;
  @override
  void initState() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);

        print(_sharedFiles.map((f) => f.toMap()));
        if (_sharedFiles.isNotEmpty) {
          getMedia();
        }
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });
    super.initState();
  }

  Future<void> getMedia() async {
    Map<String, dynamic> result = await DataHandler.analyzeZipFile(_sharedFiles.first.path);
    print(result);
    List<String> messages = result['messages'];
    List<String> imagePaths = result['images'];
    final res = ChatAnalyzer.analyze(messages, imagePaths);
    receiveChatContent(res);
  }

  List<ChatContent> chats = [];

  void receiveChatContent(ChatContent chatContent) {
    if (chatContent.messages.isEmpty) {
      return;
    }
    chats.clear();
    chats.add(chatContent);
    setState(() {});
    convertTextToPdf();
  }

  Future<void> convertTextToPdf() async {
    if (chats.isNotEmpty) {
      String text = "Contact Name: ${chats.first.chatName}\n";
      text += 'Size of Chat: ${chats.first.sizeOfChat}\n';
      text += 'Messages: \n';

      List<pw.Widget> msgs = [];
      msgs.add(pw.Text(text));

      for (var element in chats.first.messages) {
        if (chats.first.imagesPaths != null && chats.first.imagesPaths!.isNotEmpty) {
          if (element.msg!.contains('.jpg')) {
            String imgName = element.msg!.replaceRange(element.msg!.indexOf('.jpg'), element.msg!.length, '');
            if (Platform.isIOS) {
              imgName = '${imgName.split(' ').last}.jpg';
            }
            String? filePath = chats.first.imagesPaths?.firstWhere(
              (e) => e.contains(imgName),
            );
            if (filePath != null) {
              var rawImg = await chats.first.getImage(imgName);
              if (rawImg != null) {
                var image = await rawImg.toByteData(format: ImageByteFormat.png);
                msgs.add(pw.Expanded(child: pw.Image(pw.MemoryImage(image!.buffer.asUint8List()))));
                continue;
              }
            }
          }
          msgs.add(pw.Text(_getFormattedMsg(element)));
        } else {
          msgs.add(pw.Text(_getFormattedMsg(element)));
        }
      }
      final pdf = pw.Document();

      List<List<pw.Widget>> subMsgs = List.empty(growable: true);
      int pageLimit = 20;
      var counter = (msgs.length / pageLimit).ceil();
      for (int i = 0; i < counter; i++) {
        int end = i * pageLimit + pageLimit;
        if (end > msgs.length) {
          end = msgs.length;
        }
        var sub = msgs.sublist(i * pageLimit, end);
        if (sub.isNotEmpty) {
          subMsgs.add(sub);
        }
      }

      subMsgs.removeWhere((e) => e.isEmpty);

      for (var msgs in subMsgs) {
        pdf.addPage(pw.Page(build: (pw.Context context) {
          return pw.Column(mainAxisAlignment: pw.MainAxisAlignment.start, crossAxisAlignment: pw.CrossAxisAlignment.start, children: msgs);
        }));
      }

      Directory appDocDirectory = await getApplicationDocumentsDirectory();

      pdfFile = File('${appDocDirectory.path}/pdff.pdf');
      await pdfFile.writeAsBytes(await pdf.save());
      setState(() {});
      // var myFile = UploadFile(file: pdfFile, fileName: '', fileType: FileType.whatsapp, dirId: model.currentDir!.dirId, uploadStatus: UploadStatus.none, location: await model.getLocation());

      //    model.addFileForUpload(myFile, context, FileType.whatsapp);
    }
  }

  String _getFormattedMsg(MessageContent element) {
    String senderId = element.senderId!.replaceAll('PM', '').replaceAll('AM', '').replaceAll(' ', '').replaceAll('-', '');
    String? msg = element.msg;
    String date = '';
    try {
      date = element.dateTime?.toUtc().toString() ?? "";
    } catch (e) {}
    return '$senderId: $msg - $date';
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  final _sharedFiles = <SharedMediaFile>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WP"),
      ),
      body: Column(
        children: [
          Center(
            child: ElevatedButton(
              onPressed: _openWhatsApp,
              child: Text("Import Chat"),
            ),
          ),
          if (pdfFile != null) SizedBox(height: 400, child: viewPdf())
        ],
      ),
    );
  }

  Widget viewPdf() {
    return PDFView(
      filePath: pdfFile.path,
      enableSwipe: true,
      swipeHorizontal: true,
      autoSpacing: false,
      pageFling: false,
      onRender: (_pages) {
        setState(() {
          // pages = _pages;
          // isReady = true;
        });
      },
      onError: (error) {
        print(error.toString());
      },
      onPageError: (page, error) {
        print('$page: ${error.toString()}');
      },
      // onViewCreated: (PDFViewController pdfViewController) {
      //   _controller.complete(pdfViewController);
      // },
      // onPageChanged: (int page, int total) {
      //   print('page change: $page/$total');
      // },
    );
  }

  void _openWhatsApp() async {
    await LaunchApp.openApp(
      androidPackageName: 'com.whatsapp',
      iosUrlScheme: 'whatsapp://app',
      appStoreLink: 'https://apps.apple.com/us/app/whatsapp-messenger/id310633997',
    );
  }
}
