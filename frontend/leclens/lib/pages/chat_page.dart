// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
// ignore: unused_import
import 'dart:typed_data';
import 'dart:ui_web' as ui;
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';
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

  // For local/network videos (mobile/desktop)
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

  // If on web, and we pick a local file, we might store the blob or data URL here:
  String? _webLocalVideoUrl;

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
    if (!_dummyChatActive) return;
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
      _webLocalVideoUrl = null; // reset
    });

    // Dispose old controllers
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
        // If not YouTube:
        if (kIsWeb) {
          // On web, we cannot do VideoPlayerController.file(File(...)) for blob or file://
          // So we store the link in _webLocalVideoUrl if it starts with 'blob:' or 'file:'
          if (link.startsWith('blob:') || link.startsWith('file:')) {
            // We'll use _LocalWebVideoPlayer fallback
            setState(() {
              _webLocalVideoUrl = link;
              _videoReady = true;
              _isLoading = false;
            });
            return; // Don't proceed with normal Chewie
          }
          // Otherwise, if it's a normal http or https link, we can do network
          if (link.startsWith('http')) {
            await _setupChewieNetwork(link);
          } else {
            throw Exception('Unsupported local link on web: $link');
          }
        } else {
          // On mobile/desktop
          if (_isLocalFile(link)) {
            final filePath =
                link.startsWith('file://') ? link.substring(7) : link;
            await _setupChewieFile(filePath);
          } else if (link.startsWith('http')) {
            await _setupChewieNetwork(link);
          } else {
            throw Exception('Unrecognized link format: $link');
          }
        }
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

  Future<void> _setupChewieFile(String filePath) async {
    final tmpController = VideoPlayerController.file(File(filePath));
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

  Future<void> _setupChewieNetwork(String url) async {
    final tmpController = VideoPlayerController.networkUrl(Uri.parse(url));
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

  /// Let user pick a local video via file picker
  Future<void> _pickLocalVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          // Convert to file://
          final fileUri = 'file://$path';
          setState(() {
            _videoLinkController.text = fileUri;
          });
          await _loadVideoFromLink();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking file: $e');
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
    return link.startsWith("file://") || File(link).isAbsolute;
  }

  // ------------------------------------------------------------------------
  // (D) Seek / Transcript
  // ------------------------------------------------------------------------
  void _seekVideoToTime(String time) {
    if (_isYouTube && _youtubeController != null) {
      _seekYouTube(time);
    } else if (kIsWeb && _webLocalVideoUrl != null) {
      // If we are using the HTML fallback, we can't programmatically set the time easily
      // without more advanced JavaScript bridging. We might skip or do partial bridging.
      // For now, we do nothing or show a message:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeking not implemented for web local fallback.')),
      );
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

    if (_dummyChatActive) {
      setState(() {
        _chatMessages.clear();
        _dummyChatActive = false;
      });
    }
    setState(() {
      _chatMessages.add("User: $userMessage");
      _chatController.clear();
    });

    // In real usage, you'd call your API here, sending:
    //  - session_id
    //  - user_message
    //  - filepath = _videoUrl
    await Future.delayed(const Duration(seconds: 1));
    final updatedSessionId = _sessionId ?? "test_session_123";

    final updatedConversation = [
      ..._chatMessages,
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
                    // LEFT: Video region
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
                                  child: const Text("Load Video"),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _pickLocalVideo,
                                  child: const Text("Upload"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (_isLoading)
                              const Center(child: CircularProgressIndicator()),

                            // Player region
                            if (_videoReady) ...[
                              Expanded(
                                child: Builder(builder: (context) {
                                  // 1) If it's YouTube, show YT iframe player
                                  if (_isYouTube && _youtubeController != null) {
                                    return YoutubePlayer(
                                      controller: _youtubeController!,
                                      aspectRatio: 16 / 9,
                                    );
                                  }
                                  // 2) If web local fallback
                                  if (kIsWeb && _webLocalVideoUrl != null) {
                                    return _LocalWebVideoPlayer(
                                      videoUrl: _webLocalVideoUrl!,
                                    );
                                  }
                                  // 3) Otherwise, Chewie (mobile/desktop or web network)
                                  if (_chewieController != null) {
                                    return AspectRatio(
                                      aspectRatio:
                                          _videoController!.value.aspectRatio,
                                      child: Chewie(
                                        controller: _chewieController!,
                                      ),
                                    );
                                  }
                                  // If we reach here, no player available
                                  return const Center(child: Text('Video Error'));
                                }),
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
                    // RIGHT: Chat region
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

/// This widget uses an HTML <video> element to play a local file
/// on Flutter Web. By default, the standard video_player plugin can't handle
/// file:// or blob: URLs on web.
class _LocalWebVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _LocalWebVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<_LocalWebVideoPlayer> createState() => _LocalWebVideoPlayerState();
}

class _LocalWebVideoPlayerState extends State<_LocalWebVideoPlayer> {
  late final String _elementId;

  @override
  void initState() {
    super.initState();
    _elementId = 'video-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory(_elementId, widget.videoUrl);
  }

  void _registerViewFactory(String viewId, String url) {
    ui.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final video = html.VideoElement()
        ..src = url
        ..controls = true
        ..autoplay = true       // Let it attempt to autoplay
        ..muted = true          // Mute so autoplay is allowed
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';

      // Optionally remove forced .play() to rely on user pressing 'Play'
      // video.onCanPlay.listen((_) => video.play());

      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _elementId);
  }
}