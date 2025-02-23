import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart'; // <--- Add this
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../components/common_background.dart';
import '../transcripts/transcript_item.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // -----------------------------
  // 1. Controllers & states
  // -----------------------------
  final TextEditingController _videoLinkController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  String? _videoUrl;
  bool _isLoading = false;
  bool _videoReady = false;
  bool _isYouTube = false;

  // For local/network videos
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Future<void>? _initializeVideoFuture;

  // For YouTube
  YoutubePlayerController? _youtubeController;

  // Transcript
  List<TranscriptItem> _transcript = [];
  Map<String, String> _textToTimestampMap = {};

  // Chat
  String? _sessionId;
  List<String> _chatMessages = [];

  // This flag ensures the dummy chat is shown until user sends a new query.
  // After the first user query, we clear the dummy chat.
  bool _dummyChatActive = true; // <--- WHEN TRUE, SHOW DUMMY CHAT

  @override
  void initState() {
    super.initState();
    _loadLocalTranscriptJson(); // loads transcript from assets/transcripts/text_to_timestamp.json
    _loadSampleChatFromJson();  // loads the dummy chat from assets/chat/sample_chat.json
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.close();

    _videoLinkController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // (A) Load Sample Chat (DUMMY) - Remove once real API is functional
  // ------------------------------------------------------------------------
  Future<void> _loadSampleChatFromJson() async {
    if (!_dummyChatActive) return; // if somehow turned off, skip loading
    try {
      final String chatJson =
          await rootBundle.loadString('assets/chat/sample_chat.json');
      final Map<String, dynamic> data = jsonDecode(chatJson);

      setState(() {
        _sessionId = data["session_id"] ?? "test_session_123";
        final List<dynamic> conv = data["conversation"] ?? [];
        _chatMessages = conv.map((e) => e.toString()).toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error loading sample chat JSON: $e");
      }
      // If we can't load, just show a minimal default
      setState(() {
        _sessionId = "test_session_123";
        _chatMessages = [
          "AI: Hello! This is a sample conversation.",
          "User: Great, let's get started!"
        ];
      });
    }
  }

  // ------------------------------------------------------------------------
  // (B) Load Transcript from local JSON
  // ------------------------------------------------------------------------
  Future<void> _loadLocalTranscriptJson() async {
    try {
      final String dataString =
          await rootBundle.loadString('assets/transcripts/text_to_timestamp.json');
      final Map<String, dynamic> data = jsonDecode(dataString);

      setState(() {
        _textToTimestampMap = data.map((k, v) => MapEntry(k, v.toString()));
      });

      // Build _transcript from that map
      final items = <TranscriptItem>[];
      _textToTimestampMap.forEach((content, time) {
        items.add(TranscriptItem(time: time, content: content));
      });
      setState(() {
        _transcript = items;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading local JSON: $e');
      }
    }
  }

  // ------------------------------------------------------------------------
  // (C) Load the Video
  // ------------------------------------------------------------------------
  /// Called when user either pastes a link or picks a file.
  Future<void> _loadVideoFromLink() async {
    final link = _videoLinkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid video link or path.')),
      );
      return;
    }
    setState(() {
      _videoUrl = link;
      _isLoading = true;
      _videoReady = false;
      _isYouTube = _isYouTubeLink(link);
    });

    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _youtubeController?.close();
    _youtubeController = null;

    try {
      if (_isYouTube) {
        final videoId = _extractYouTubeVideoId(link);
        if (videoId == null) throw Exception("Invalid YouTube link");

        _youtubeController = YoutubePlayerController(
          params: const YoutubePlayerParams(showFullscreenButton: true),
        )..loadVideoById(videoId: videoId);

        setState(() {
          _videoReady = true;
          _isLoading = false;
        });
      } else {
        VideoPlayerController tmpController;
        if (_isLocalFile(link)) {
          // e.g. file://... or absolute
          final filePath = link.startsWith('file://') ? link.substring(7) : link;
          tmpController = VideoPlayerController.file(File(filePath));
        } else {
          tmpController = VideoPlayerController.networkUrl(Uri.parse(link));
        }

        _videoController = tmpController;
        _initializeVideoFuture = _videoController!.initialize();
        await _initializeVideoFuture;
        if (!mounted) return;

        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
        );

        setState(() {
          _videoReady = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading video: $e');
      }
      setState(() {
        _isLoading = false;
        _videoReady = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load video.')),
      );
    }
  }

  /// Opens a file picker so the user can select a local video file.
  /// Then automatically loads it.
  Future<void> _pickLocalVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          // Convert to file:// schema for consistency
          final fileUri = 'file://$path';
          // Put it in the text field
          setState(() {
            _videoLinkController.text = fileUri;
          });
          // Then load
          await _loadVideoFromLink();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error picking file: $e");
      }
    }
  }

  bool _isYouTubeLink(String link) {
    return link.contains("youtube.com") || link.contains("youtu.be");
  }

  String? _extractYouTubeVideoId(String url) {
    return YoutubePlayerController.convertUrlToId(url);
  }

  bool _isLocalFile(String link) {
    // e.g. 'file://' or absolute path
    return link.startsWith("file://") || File(link).isAbsolute;
  }

  // ------------------------------------------------------------------------
  // (D) Seek / Transcript
  // ------------------------------------------------------------------------
  void _seekVideoToTime(String time) {
    if (_isYouTube && _youtubeController != null) {
      _seekYouTube(time);
    } else {
      _seekChewie(time);
    }
  }

  void _seekYouTube(String time) {
    try {
      final parts = time.split(':').map(int.parse).toList();
      int seconds = 0;
      if (parts.length == 2) {
        seconds = parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        seconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      _youtubeController?.seekTo(seconds: seconds.toDouble());
      _youtubeController?.playVideo();
    } catch (e) {
      if (kDebugMode) print('Error seeking YouTube time: $e');
    }
  }

  void _seekChewie(String time) {
    try {
      final parts = time.split(':').map(int.parse).toList();
      int seconds = 0;
      if (parts.length == 2) {
        seconds = parts[0] * 60 + parts[1];
      } else if (parts.length == 3) {
        seconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
      final position = Duration(seconds: seconds);
      _videoController?.seekTo(position);
      _videoController?.play();
    } catch (e) {
      if (kDebugMode) print('Error seeking local video time: $e');
    }
  }

  // ------------------------------------------------------------------------
  // (E) Chat logic: Send message -> Refresh conversation
  // ------------------------------------------------------------------------
  Future<void> _sendChatMessage() async {
    final userMessage = _chatController.text.trim();
    if (userMessage.isEmpty) return;

    // If dummy chat is active, remove it now (once the user sends a message).
    // AFTER API is functional, we can remove this logic.
    if (_dummyChatActive) {
      setState(() {
        _chatMessages.clear();
        _dummyChatActive = false;
      });
    }

    // Immediately show user message
    setState(() {
      _chatMessages.add("User: $userMessage");
      _chatController.clear();
    });

    // In real usage, you'd call your API here, sending:
    //  - session_id
    //  - user_message
    //  - filepath = _videoUrl
    // For demonstration, we do a dummy response:
    await Future.delayed(const Duration(seconds: 1));
    final updatedSessionId = _sessionId ?? "test_session_123";

    final updatedConversation = [
      ..._chatMessages,
      // Show that we're including the file path in the conversation for debugging
      "AI: The server acknowledges your file path: ${_videoUrl ?? 'no file path'}",
      "AI: This is a dummy response from the server."
    ];

    setState(() {
      _sessionId = updatedSessionId;
      _chatMessages = updatedConversation;
    });
  }

  // ------------------------------------------------------------------------
  // (F) Download Non-YouTube
  // ------------------------------------------------------------------------
  Future<void> _downloadVideo() async {
    if (_videoUrl == null) return;
    if (_isYouTube) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading YouTube videos is restricted.")),
      );
      return;
    }
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse(_videoUrl!));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", 'video.mp4')
            ..style.display = 'none';
          html.document.body!.append(anchor);
          anchor.click();
          anchor.remove();
          html.Url.revokeObjectUrl(url);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video download initiated')),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error downloading video on web: $e');
      }
    } else {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        try {
          final response = await http.get(Uri.parse(_videoUrl!));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            Directory? directory;
            if (Platform.isAndroid) {
              directory = await getExternalStorageDirectory();
            } else if (Platform.isIOS) {
              directory = await getApplicationDocumentsDirectory();
            } else {
              directory = await getApplicationDocumentsDirectory();
            }
            if (directory == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to access storage')),
              );
              return;
            }
            final filePath = '${directory.path}/video.mp4';
            final file = File(filePath);
            await file.writeAsBytes(bytes);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video downloaded')),
              );
            }
          }
        } catch (e) {
          if (kDebugMode) print('Error downloading video: $e');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied')),
          );
        }
      }
    }
  }

  // ------------------------------------------------------------------------
  // (G) Build UI
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return CommonBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // Main: row with video (left) + chat (right)
              Expanded(
                child: Row(
                  children: [
                    // LEFT: Video
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Colors.white60,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            // Enter link + Load + Upload
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _videoLinkController,
                                    decoration: const InputDecoration(
                                      hintText: "Enter a YouTube or local file path",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _loadVideoFromLink,
                                  child: const Text("Load YouTube Video"),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _pickLocalVideo,
                                  child: const Text("Upload Video File"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Loading
                            if (_isLoading)
                              const Center(child: CircularProgressIndicator()),

                            // Player
                            if (_videoReady) ...[
                              Expanded(
                                child: _isYouTube && _youtubeController != null
                                    ? YoutubePlayer(
                                        controller: _youtubeController!,
                                        aspectRatio: 16 / 9,
                                      )
                                    : _chewieController != null
                                        ? AspectRatio(
                                            aspectRatio:
                                                _videoController!.value.aspectRatio,
                                            child: Chewie(
                                              controller: _chewieController!,
                                            ),
                                          )
                                        : const Center(child: Text('Video Error')),
                              ),
                              const SizedBox(height: 8),
                              if (!_isYouTube)
                                ElevatedButton(
                                  onPressed: _downloadVideo,
                                  child: const Text('Download Video'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // RIGHT: Chat
                    Expanded(
                      flex: 1,
                      child: Container(
                        color: Colors.white54,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            const Text(
                              "Chat Assistant",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _chatMessages.length,
                                itemBuilder: (context, index) {
                                  final line = _chatMessages[index];
                                  final isUser = line.startsWith("User:");
                                  return Align(
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      margin: const EdgeInsets.symmetric(vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? Colors.blueAccent
                                            : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        line,
                                        style: TextStyle(
                                          color: isUser ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // chat input
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _chatController,
                                    decoration: const InputDecoration(
                                      hintText: "Type your message...",
                                    ),
                                    onSubmitted: (_) => _sendChatMessage(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: _sendChatMessage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Transcript at bottom
              Container(
                height: 200.0,
                margin: const EdgeInsets.only(top: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: _transcript.isNotEmpty
                    ? ListView.builder(
                        itemCount: _transcript.length,
                        itemBuilder: (context, index) {
                          final item = _transcript[index];
                          return ListTile(
                            leading: Text(
                              item.time,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            title: Text(
                              item.content,
                              style: const TextStyle(color: Colors.black),
                            ),
                            onTap: () {
                              _seekVideoToTime(item.time);
                            },
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'No transcript available.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
