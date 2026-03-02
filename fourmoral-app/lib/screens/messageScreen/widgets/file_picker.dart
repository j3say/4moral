import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/messageScreen/controller/message_controller.dart';
import 'package:fourmoral/screens/messageScreen/services/message_service.dart';
import 'package:fourmoral/screens/messageScreen/widgets/chat_input_filed.dart';
import 'package:fourmoral/widgets/contact_selection_list.dart';
import 'package:image_picker/image_picker.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:get/get.dart';

class FilePickerMenu extends StatelessWidget {
  final MessageCnt messageCnt;
  final String profileuserphone;

  const FilePickerMenu({
    super.key,
    required this.messageCnt,
    required this.profileuserphone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2.0),
      child: Obx(
        () =>
            messageCnt.isUploading.value
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : CustomPopupMenu(
                  menuBuilder:
                      () => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFF3A3A3A),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildOptionButton(
                                    icon: Icons.image,
                                    color: Colors.purple,
                                    onTap: () async {
                                      messageCnt.controller.hideMenu();
                                      messageCnt.isUploading.value = true;
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                      );
                                      if (pickedFile != null) {
                                        final file = File(pickedFile.path);
                                        await MessageService.sendEncryptedFile(
                                          file: file,
                                          fileType: "photo",
                                          receiverPublicKey:
                                              messageCnt.receiverPublicKey!,
                                          userPhone: messageCnt.userphone!,
                                          receiverPhone: profileuserphone,
                                          clearReply:
                                              () => messageCnt.clearReply(),
                                          needsScroll: messageCnt.needsScroll,
                                          // ref: messageCnt.dbRef,
                                          // refNotification:
                                          //     messageCnt.dbNotificationRef,
                                          replyData:
                                              messageCnt.replyingToMessage,
                                        );
                                      }
                                      messageCnt.isUploading.value = false;
                                    },
                                  ),
                                  buildOptionButton(
                                    icon: Icons.camera_alt,
                                    color: Colors.teal,
                                    onTap: () async {
                                      messageCnt.controller.hideMenu();
                                      messageCnt.isUploading.value = true;
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.camera,
                                      );
                                      if (pickedFile != null) {
                                        final file = File(pickedFile.path);
                                        await MessageService.sendEncryptedFile(
                                          file: file,
                                          fileType: "photo",
                                          receiverPublicKey:
                                              messageCnt.receiverPublicKey!,
                                          userPhone: messageCnt.userphone!,
                                          receiverPhone: profileuserphone,
                                          clearReply:
                                              () => messageCnt.clearReply(),
                                          needsScroll: messageCnt.needsScroll,
                                          replyData:
                                              messageCnt.replyingToMessage,
                                        );
                                      }
                                      messageCnt.isUploading.value = false;
                                    },
                                  ),
                                  buildOptionButton(
                                    icon: Icons.videocam,
                                    color: Colors.redAccent,
                                    onTap: () async {
                                      messageCnt.controller.hideMenu();
                                      messageCnt.isUploading.value = true;
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickVideo(
                                        source: ImageSource.gallery,
                                      );
                                      if (pickedFile != null) {
                                        final file = File(pickedFile.path);
                                        await MessageService.sendEncryptedFile(
                                          file: file,
                                          fileType: "video",
                                          receiverPublicKey:
                                              messageCnt.receiverPublicKey!,
                                          userPhone: messageCnt.userphone!,
                                          receiverPhone: profileuserphone,
                                          clearReply:
                                              () => messageCnt.clearReply(),
                                          needsScroll: messageCnt.needsScroll,
                                          replyData:
                                              messageCnt.replyingToMessage,
                                        );
                                      }
                                      messageCnt.isUploading.value = false;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildOptionButton(
                                    icon: Icons.audio_file,
                                    color: Colors.orange,
                                    onTap: () async {
                                      messageCnt.controller.hideMenu();
                                      messageCnt.isUploading.value = true;
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                            type: FileType.audio,
                                          );
                                      if (result != null &&
                                          result.files.single.path != null) {
                                        final file = File(
                                          result.files.single.path!,
                                        );
                                        await MessageService.sendEncryptedFile(
                                          file: file,
                                          fileType: "audio",
                                          receiverPublicKey:
                                              messageCnt.receiverPublicKey!,
                                          userPhone: messageCnt.userphone!,
                                          receiverPhone: profileuserphone,
                                          clearReply:
                                              () => messageCnt.clearReply(),
                                          needsScroll: messageCnt.needsScroll,

                                          replyData:
                                              messageCnt.replyingToMessage,
                                        );
                                      }
                                      messageCnt.isUploading.value = false;
                                    },
                                  ),
                                  buildOptionButton(
                                    icon: Icons.document_scanner_rounded,
                                    color: Colors.green,
                                    onTap: () async {
                                      messageCnt.controller.hideMenu();
                                      messageCnt.isUploading.value = true;
                                      FilePickerResult? result =
                                          await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: [
                                              'pdf',
                                              'doc',
                                              'apk',
                                              'zip',
                                            ],
                                            allowMultiple: true,
                                          );

                                      if (result != null) {
                                        for (var path in result.paths) {
                                          if (path != null) {
                                            final file = File(path);
                                            await MessageService.sendEncryptedFile(
                                              file: file,
                                              fileType: "document",
                                              receiverPublicKey:
                                                  messageCnt.receiverPublicKey!,
                                              userPhone: messageCnt.userphone!,
                                              receiverPhone: profileuserphone,
                                              clearReply:
                                                  () => messageCnt.clearReply(),
                                              needsScroll:
                                                  messageCnt.needsScroll,
                                              // ref: messageCnt.dbRef,
                                              // refNotification:
                                              //     messageCnt.dbNotificationRef,
                                              replyData:
                                                  messageCnt.replyingToMessage,
                                            );
                                          }
                                        }
                                      }
                                      messageCnt.isUploading.value = false;
                                    },
                                  ),
                                  buildOptionButton(
                                    icon: Icons.contact_page_rounded,
                                    color: Colors.amber,
                                    onTap: () {
                                      messageCnt.controller.hideMenu();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => ContactSelection(
                                                profileuserphone:
                                                    profileuserphone,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  pressType: PressType.singleClick,
                  verticalMargin: -10,
                  controller: messageCnt.controller,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.add, size: 24, color: white),
                  ),
                ),
      ),
    );
  }
}
