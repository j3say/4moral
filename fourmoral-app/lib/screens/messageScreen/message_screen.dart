import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:dio/dio.dart' as di;
import 'package:external_path/external_path.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_widgets.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
import 'package:fourmoral/screens/messageScreen/media_page.dart';
import 'package:fourmoral/screens/messageScreen/services/message_service.dart';
import 'package:fourmoral/screens/messageScreen/widgets/chat_input_filed.dart';
import 'package:fourmoral/screens/messageScreen/widgets/message_bubble.dart';
import 'package:fourmoral/screens/messageScreen/widgets/scroll_to_bottom_button.dart';
import 'package:fourmoral/screens/otherProfileScreen/other_profile_screen.dart';
import 'package:fourmoral/screens/videoAndVoiceCall/call_manager.dart';
import 'package:fourmoral/screens/walletScreen/wallet_screen.dart';
import 'package:fourmoral/utils/message_utils.dart';
// import 'package:gallery_picker/gallery_picker.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pointycastle/pointycastle.dart' as crypto;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class Message extends StatefulWidget {
  const Message({
    super.key,
    this.userimg,
    this.username,
    this.profileuserphone,
    this.storyReply,
    this.storyImage,
    this.locationLat, // Add this
    this.locationLong, // Add this
  });

  final String? userimg;
  final String? username;
  final String? profileuserphone;
  final String? storyReply;
  final String? storyImage;
  final double? locationLat; // Add this
  final double? locationLong; // Add this

  @override
  _MessageState createState() => _MessageState();
}

enum MenuItemType { EDIT, DUPLICATE }

class _MessageState extends State<Message> with WidgetsBindingObserver {
  final messageCnt = Get.put(MessageCnt());
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  double perMinuteCharge = 10.0;
  late StreamSubscription<DatabaseEvent> _messageSub;
  final storage = const FlutterSecureStorage();
  bool showScrollButton = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(() {
      if (_scrollController.offset <
          _scrollController.position.maxScrollExtent - 100) {
        if (!showScrollButton) setState(() => showScrollButton = true);
      } else {
        if (showScrollButton) setState(() => showScrollButton = false);
      }
    });

    messageCnt.userphone =
        FirebaseAuth.instance.currentUser?.phoneNumber.toString();
    messageCnt.userName =
        FirebaseAuth.instance.currentUser?.displayName.toString();
    _initSpeech();
    _initPrivateKeyAndMessages();
    Future.delayed(Duration(milliseconds: 300), _scrollToBottom);

    messageCnt.ref = FirebaseDatabase.instance.ref().child('Messages/');
    // messageCnt.getMessages(profileuserphone: widget.profileuserphone);
    messageCnt.fetched.value ? messageCnt.needsScroll.value = true : null;
    downloadedFileCheck();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.storyReply != null && widget.storyReply!.isNotEmpty) {
        _sendStoryReply();
      }
      if (widget.locationLat != null && widget.locationLong != null) {
        _sendLocationShare();
      }
    });
  }

  Future<void> _initPrivateKeyAndMessages() async {
    await _initializeKeys(); // Ensure private key is loaded
    _listenToMessages(); // Now it's safe to start listening
  }

  @override
  void didChangeMetrics() {
    final viewInsets = WidgetsBinding.instance.window.viewInsets;
    final keyboardOpen = viewInsets.bottom > 0.0;
    if (keyboardOpen) {
      Future.delayed(Duration(milliseconds: 200), _scrollToBottom);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageSub.cancel(); // 🔥 Cancel the subscription to avoid memory leaks
    super.dispose();
  }

  Future<void> _initializeKeys() async {
    String? priv = await storage.read(key: 'private_key');
    String? pub = await storage.read(key: 'public_key');
    // TODO: Please Enable This If Condition To Live Mode

    if (priv == null || pub == null) {
      final pair = _generateRSAKeyPair();
      priv = pair['private'];
      pub = pair['public'];
      await storage.write(key: 'private_key', value: priv);
      await storage.write(key: 'public_key', value: pub);

      await FirebaseFirestore.instance
          .collection('Users')
          .where('mobileNumber', isEqualTo: widget.profileuserphone ?? '')
          .limit(1)
          .get()
          .then((value) {
            value.docs[0].reference.update({'public_key': pub});
          });
    }
    final receiverDoc =
        await FirebaseFirestore.instance
            .collection('Users')
            .where('mobileNumber', isEqualTo: widget.profileuserphone ?? '')
            .limit(1)
            .get();

    messageCnt.receiverPublicKey = receiverDoc.docs.first.data()['public_key'];

    if (mounted) {
      setState(() {
        messageCnt.privateKey = priv;
        messageCnt.publicKey = pub;
      });
    }
  }

  Map<String, String> _generateRSAKeyPair() {
    final keyGen = crypto.KeyGenerator("RSA")..init(
      crypto.ParametersWithRandom(
        crypto.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 5),
        crypto.SecureRandom("Fortuna")..seed(
          crypto.KeyParameter(Uint8List.fromList(List.generate(32, (_) => 1))),
        ),
      ),
    );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as crypto.RSAPublicKey;
    final privateKey = pair.privateKey as crypto.RSAPrivateKey;

    final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
    final privatePem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    return {'public': publicPem, 'private': privatePem};
  }

  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          setState(() => _isListening = false);
        }
        // ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        //   SnackBar(content: Text('Error: ${errorNotification.errorMsg}')),
        // );
      },
    );
  }

  void _listen() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      //   const SnackBar(content: Text('Microphone permission denied')),
      // );
      return;
    }

    if (!_isListening) {
      if (mounted) {
        setState(() => _isListening = true);
      }

      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Add space if the controller already has text
            if (messageCnt.messageController.text.isNotEmpty &&
                !messageCnt.messageController.text.endsWith(' ')) {
              messageCnt.messageController.text += ' ';
            }
            messageCnt.messageController.text += result.recognizedWords;
            // Move cursor to the end
            messageCnt.messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: messageCnt.messageController.text.length),
            );
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        partialResults: false,
      );
    } else {
      if (mounted) {
        setState(() => _isListening = false);
      }
      _speech.stop();
    }
  }

  void _sendLocationShare() {
    messageCnt.addMessage(
      "${widget.locationLat},${widget.locationLong}",
      profileuserphone: widget.profileuserphone ?? "",
      type: "location",
    );
    messageCnt.scrolltobottom();
  }

  void _sendStoryReply() {
    if (widget.storyReply != null && widget.storyReply!.isNotEmpty) {
      // Send the story reply text
      messageCnt.addMessage(
        widget.storyReply!,
        profileuserphone: widget.profileuserphone ?? "",
        type: "story_reply",
        videoUrl:
            widget.storyImage ??
            "", // Using videoUrl field to store story image
      );

      // Scroll to bottom after sending
      messageCnt.scrolltobottom();
    }
  }

  void _setReply(Map<String, dynamic> message) {
    setState(() {
      messageCnt.replyingToMessage.value = {
        'id': message['id'],
        'message': message['decrypted'],
        'type': message['type'],
      };
    });
  }

  void _clearReply() {
    setState(() {
      messageCnt.replyingToMessage.value = {};
    });
  }

  String getFileName(String url) {
    RegExp regExp = RegExp(r'.+(\/|%2F)(.+)\?.+');
    var matches = regExp.allMatches(url);
    if (matches.isEmpty) return url;

    var match = matches.elementAt(0);
    return Uri.decodeFull(match.group(2)!);
  }

  var downloadProgress = 0.0;

  Future downloadFile({String? imageSrc, String? imageName}) async {
    di.Dio dio = di.Dio();
    String path = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOAD,
    );
    var imageDownloadPath = '$path/$imageName';
    await dio.download(
      imageSrc ?? "",
      imageDownloadPath,
      onReceiveProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          downloadProgress = received.toDouble() / total.toDouble();
        });
      },
    );
    return imageDownloadPath;
  }

  Future<void> downloadedFileCheck() async {
    String path = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOWNLOAD,
    );

    for (int i = 0; i < messageCnt.messageslist.length; i++) {
      if (messageCnt.messageslist[i]['type'] == 'document') {
        bool check =
            await File(
              "$path/${getFileName(messageCnt.messageslist[i]['message'])}",
            ).exists();

        messageCnt.ref
            ?.child(messageCnt.messageslist[i]['mainKey'])
            .child('Data')
            .child(messageCnt.messageslist[i]['key'])
            .update({'documentCheck': check});
      }
    }
  }

  void _listenToMessages() {
    final phones = [messageCnt.userphone, widget.profileuserphone]..sort();
    final chatPath = "${phones[0]}-${phones[1]}"; // Consistent chatPath

    _messageSub = FirebaseDatabase.instance
        .ref()
        .child('Messages')
        .child(chatPath)
        .child('Data')
        .onValue
        .listen((event) async {
          final rawData = event.snapshot.value;

          if (rawData == null) {
            messageCnt.decryptedMessages.value = [];
            messageCnt.isLoading.value = false;
            return;
          }

          final data = rawData as Map<dynamic, dynamic>;

          // Sort messages by time
          final sortedList =
              data.entries
                  .map((entry) => Map<String, dynamic>.from(entry.value))
                  .toList()
                ..sort((a, b) {
                  final t1 =
                      DateTime.tryParse(a['time'] ?? '') ?? DateTime.now();
                  final t2 =
                      DateTime.tryParse(b['time'] ?? '') ?? DateTime.now();
                  return t1.compareTo(t2);
                });

          // Decrypt messages
          final decryptedList = await Future.wait(
            sortedList.map((msg) async {
              final encrypted = msg['message'];
              try {
                final decrypted = await MessageUtils.decryptMessage(
                  encrypted,
                  messageCnt.privateKey ?? "",
                );

                // Decrypt reply message too (if needed)
                if (msg['isReply'] == true &&
                    msg['replyTo'] != null &&
                    msg['replyTo']['message'] != null) {
                  try {
                    final replyDecrypted = await MessageUtils.decryptMessage(
                      msg['replyTo']['message'],
                      messageCnt.privateKey!,
                    );
                    msg['replyTo']['message'] = replyDecrypted;
                  } catch (e) {
                    // If decryption fails, keep original
                  }
                }

                return {...msg, 'decrypted': decrypted};
              } catch (e) {
                return {...msg, 'decrypted': encrypted};
              }
            }),
          );

          // Update UI
          print("decryptedList $decryptedList");
          messageCnt.decryptedMessages.value = decryptedList;
          messageCnt.isLoading.value = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    if (messageCnt.needsScroll.value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => messageCnt.scrolltobottom(),
      );
      messageCnt.needsScroll.value = false;
    }
    messageCnt.fetched.value ? messageCnt.scrolltobottom() : null;
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: blue,
        flexibleSpace: SafeArea(
          child: Container(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: black),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => OtherProfileScreen(
                              mobileNumber: widget.profileuserphone ?? "",
                            ),
                      ),
                    );
                  },
                  child: profileImageWidget(
                    size.height,
                    size.width,
                    widget.userimg,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => OtherProfileScreen(
                              mobileNumber: widget.profileuserphone ?? "",
                            ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        widget.username ?? "",
                        style: TextStyle(
                          fontSize: 16,
                          color: black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // InkWell(
                //   onTap: () async {
                //     final callManager = CallManager();
                //     final usersRef = FirebaseFirestore.instance.collection(
                //       'Users',
                //     );
                //     final callerUid = await callManager
                //         .getFirestoreDocumentIdByUid(
                //           FirebaseAuth.instance.currentUser?.uid ?? "",
                //         );
                //     final receiverDocId = await callManager
                //         .getFirestoreDocumentIdByPhone(
                //           widget.profileuserphone.toString(),
                //         );

                //     final callerSnapshot = await usersRef.doc(callerUid).get();
                //     final receiverSnapshot =
                //         await usersRef.doc(receiverDocId).get();

                //     final callerData = callerSnapshot.data();
                //     final callerRole =
                //         (callerData?['type'] ?? 'standard')
                //             .toString()
                //             .toLowerCase();
                //     final receiverData = receiverSnapshot.data();
                //     final receiverRole =
                //         (receiverData?['type'] ?? 'standard')
                //             .toString()
                //             .toLowerCase();

                //     if (callerRole == 'standard' && receiverRole == 'mentor') {
                //       final balance =
                //           (callerData?['walletBalance'] as num?)?.toDouble() ??
                //           0.0;

                //       if (balance < perMinuteCharge) {
                //         showDialog(
                //           context: context,
                //           builder:
                //               (ctx) => AlertDialog(
                //                 title: const Text("Insufficient Balance"),
                //                 content: const Text(
                //                   "Your wallet balance is low.\nPlease add money to start the call.",
                //                 ),
                //                 actions: [
                //                   TextButton(
                //                     onPressed: () {
                //                       Navigator.of(ctx).pop();
                //                       Get.to(() => WalletScreen());
                //                       // Navigate to wallet top-up screen if needed
                //                     },
                //                     child: const Text("Add Money"),
                //                   ),
                //                 ],
                //               ),
                //         );
                //         return;
                //       }
                //     }

                //     // final invitees = await getInvitesFromTextCtrl(
                //     //   widget.profileuserphone ?? "",
                //     // );

                //     // ZegoUIKitPrebuiltCallInvitationService().send(
                //     //   invitees: invitees,
                //     //   isVideoCall: false, // Set to false for voice call
                //     //   timeoutSeconds: 60,
                //     //   resourceID: 'zego_uikit_call',
                //     //   customData: 'Optional custom data',
                //     //   notificationTitle: 'Incoming Call',
                //     //   notificationMessage: 'You have a new call invitation',
                //     // );
                //   },
                //   child: const Icon(Icons.call),
                // ),
                // SizedBox(width: 10),
                // buildVideoCallManagerButton(context),
                // ZegoCancelInvitationButton(invitees: []),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'disappearing') {
                      _showDisappearingMessagesDialog(
                        context,
                        messageCnt,
                        widget.profileuserphone ?? "",
                      );
                    } else if (value == 'clear_chat') {
                    } else if (value == 'media') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MediaPage(
                                profileuserphone: widget.profileuserphone ?? "",
                              ),
                        ),
                      );
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'disappearing',
                          child: Row(
                            children: [
                              Icon(Icons.timer_outlined),
                              SizedBox(width: 10),
                              Text('Disappearing messages'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'media',
                          child: Row(
                            children: [
                              Icon(Icons.photo_library),
                              SizedBox(width: 10),
                              Text('Media'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'clear_chat',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded),
                              SizedBox(width: 10),
                              Text('Clear all chat'),
                            ],
                          ),
                        ),
                      ],
                ),

                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Chat Encryption'),
                            content: const Text(
                              'This chat is end-to-end encrypted. Only you and the recipient can read the messages.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                    );
                  },
                  child: Icon(Icons.info_outline),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/chat_background.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Obx(
            () =>
                messageCnt.isLoading.value
                    ? Center(
                      child: CupertinoActivityIndicator(
                        radius: 15,
                        color: Colors.black,
                      ),
                    )
                    : Column(
                      children: <Widget>[
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: messageCnt.decryptedMessages.length,
                            physics: BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final msg = messageCnt.decryptedMessages[index];
                              final isMe =
                                  msg['sender'] == messageCnt.userphone;
                              return MessageBubble(
                                messageData: msg,
                                isSender: isMe,
                                onSwipeReply: () => _setReply(msg),
                                receiverPublicKey:
                                    messageCnt.receiverPublicKey ?? "",
                                userPrivateKey: messageCnt.privateKey ?? "",
                              );
                            },
                          ),
                        ),
                        if (messageCnt.replyingToMessage.isNotEmpty)
                          Container(
                            color: Colors.grey[200],
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Replying to: ${messageCnt.replyingToMessage['message']}',
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearReply,
                                ),
                              ],
                            ),
                          ),

                        ChatInputField(
                          profileuserphone: widget.profileuserphone ?? "",
                          onSend: (value) {
                            if (messageCnt.messageController.text
                                .trim()
                                .isNotEmpty) {
                              final replyData =
                                  messageCnt.replyingToMessage.isNotEmpty
                                      ? {
                                        'isReply': true,
                                        'replyTo': {
                                          'id':
                                              messageCnt
                                                  .replyingToMessage['id'],
                                          'message':
                                              messageCnt
                                                  .replyingToMessage['message'],
                                          'type':
                                              messageCnt
                                                  .replyingToMessage['type'] ??
                                              'text',
                                        },
                                      }
                                      : null;

                              print("replyData $replyData");
                              MessageService.addMessage(
                                messageCnt.messageController.text,
                                profileuserphone: widget.profileuserphone ?? "",
                                profileusername:
                                    FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.displayName
                                        .toString() ??
                                    "",
                                replyData: replyData,
                                userphone:
                                    FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.phoneNumber
                                        .toString() ??
                                    "",
                                receiverPublicKey: messageCnt.receiverPublicKey,
                                clearReply: () {
                                  messageCnt.replyingToMessage.value = {};
                                },
                                messageController: messageCnt.messageController,
                                needsScroll: true.obs,
                              );

                              messageCnt.scrolltobottom();
                              messageCnt.messageController.clear();
                              messageCnt.clearReply();
                            }
                          },
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
          ),
          if (showScrollButton)
            ScrollToBottomButton(onPressed: _scrollToBottom, visible: true),
        ],
      ),
    );
  }

  InkWell buildVideoCallManagerButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        final callManager = CallManager();
        final usersRef = FirebaseFirestore.instance.collection('Users');
        final callerUid = await callManager.getFirestoreDocumentIdByUid(
          FirebaseAuth.instance.currentUser?.uid ?? "",
        );
        final receiverDocId = await callManager.getFirestoreDocumentIdByPhone(
          widget.profileuserphone.toString(),
        );

        final callerSnapshot = await usersRef.doc(callerUid).get();
        final receiverSnapshot = await usersRef.doc(receiverDocId).get();

        final callerData = callerSnapshot.data();
        final callerRole =
            (callerData?['type'] ?? 'standard').toString().toLowerCase();
        final receiverData = receiverSnapshot.data();
        final receiverRole =
            (receiverData?['type'] ?? 'standard').toString().toLowerCase();

        if (callerRole == 'standard' && receiverRole == 'mentor') {
          final balance =
              (callerData?['walletBalance'] as num?)?.toDouble() ?? 0.0;

          if (balance < perMinuteCharge) {
            // 🚫 Insufficient balance, show dialog
            showDialog(
              context: context,
              builder:
                  (ctx) => AlertDialog(
                    title: const Text("Insufficient Balance"),
                    content: const Text(
                      "Your wallet balance is low.\nPlease add money to start the call.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Get.to(() => WalletScreen());
                          // Navigate to wallet top-up screen if needed
                        },
                        child: const Text("Add Money"),
                      ),
                    ],
                  ),
            );
            return; // 🔴 Don’t send invitation
          }
        }

        // final invitees = await getInvitesFromTextCtrl(
        //   widget.profileuserphone ?? "",
        // );

        // ZegoUIKitPrebuiltCallInvitationService().send(
        //   invitees: invitees,
        //   isVideoCall: true, // Set to false for voice call
        //   timeoutSeconds: 60,
        //   resourceID: 'zego_uikit_call',
        //   customData: 'Optional custom data',
        //   notificationTitle: 'Incoming Call',
        //   notificationMessage: 'You have a new call invitation',
        // );
      },
      child: const Icon(Icons.video_call),
    );
  }

  void _showDisappearingMessagesDialog(
    BuildContext context,
    MessageCnt controller,
    String profileuserphone,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disappearing messages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Messages will disappear after the specified time.'),
              const SizedBox(height: 20),
              Obx(
                () => SwitchListTile(
                  title: const Text('Enable disappearing messages'),
                  value: controller.disappearEnabled.value,
                  onChanged: (value) {
                    if (!value) {
                      controller.setDisappearingMessages(0, profileuserphone);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildDurationOption(
                context,
                '24 hours',
                24 * 60 * 60,
                controller,
                profileuserphone,
              ),
              _buildDurationOption(
                context,
                '7 days',
                7 * 24 * 60 * 60,
                controller,
                profileuserphone,
              ),
              _buildDurationOption(
                context,
                '90 days',
                90 * 24 * 60 * 60,
                controller,
                profileuserphone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDurationOption(
    BuildContext context,
    String label,
    int durationInSeconds,
    MessageCnt controller,
    String profileuserphone,
  ) {
    return ListTile(
      title: Text(label),
      leading: Radio<int>(
        value: durationInSeconds,
        groupValue:
            controller.disappearEnabled.value
                ? controller.disappearDuration.value
                : 0,
        onChanged: (value) {
          controller.setDisappearingMessages(value!, profileuserphone);
          Navigator.pop(context);
        },
      ),
    );
  }
}
