// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory, Platform;
import 'dart:ui_web' as ui;

import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// --- PDF & printing imports ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';

import '../components/common_background.dart';
import '../transcripts/transcript_item.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // -----------------------------
  // 1. Controllers & states
  // -----------------------------
  final TextEditingController _videoLinkController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  // Video loading
  // ignore: unused_field
  String? _videoUrl;
  bool _isLoading = false;
  bool _videoReady = false;
  bool _isYouTube = false;

  // For local/network videos on mobile/desktop
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Future<void>? _initializeVideoFuture;

  // For YouTube
  YoutubePlayerController? _youtubeController;

  // Transcript at bottom
  List<TranscriptItem> _transcript = [];

  // Chat and session
  String? _sessionId;
  List<String> _chatMessages = [];

  // Dummy chat logic (remove once real API fully integrated)
  bool _dummyChatActive = true;

  // Web local video fallback
  String? _webLocalVideoUrl;

  @override
  void initState() {
    super.initState();
    // Optionally load something on init
    // _loadLocalTranscriptJson();
    // _loadSampleChatFromJson();
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
  // (A) Upload the Video Link to the Backend
  // ------------------------------------------------------------------------
  Future<void> _uploadVideoToServer(String url) async {
    final apiUrl = 'http://127.0.0.1:5000/upload';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'youtube_url': url}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final msg = data['message'] ?? 'No message';
        final session = data['session_id'] ?? '';
        setState(() {
          _sessionId = session;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$msg (session: $session)')),
        );
      } else {
        if (kDebugMode) {
          print('Error uploading video: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in _uploadVideoToServer: $e');
      }
    }
  }

  // ------------------------------------------------------------------------
  // (B) Ask a Question -> Refresh Chat & Timestamps
  // ------------------------------------------------------------------------
  Future<void> _askServer(String question) async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not established. Please upload video first.')),
      );
      return;
    }

    final apiUrl = 'http://127.0.0.1:5000/ask';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'question': question,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final conversation = data['conversation'] as List<dynamic>? ?? [];
        final relevantStamps = data['relevant_time_stamps'] as List<dynamic>? ?? [];

        // Convert conversation to chat lines
        final newChatList = <String>[];
        for (var item in conversation) {
          if (item is Map) {
            if (item.containsKey('USER')) {
              newChatList.add('User: ${item['USER']}');
            } else if (item.containsKey('AI')) {
              newChatList.add('AI: ${item['AI']}');
            }
          }
        }

        // Convert relevant_time_stamps to transcript
        final newTranscript = <TranscriptItem>[];
        for (var stamp in relevantStamps) {
          if (stamp is Map) {
            final sentence = stamp['sentence']?.toString() ?? '';
            final rawTs = stamp['timestamp'] ?? 0.0;
            double sec = 0.0;
            if (rawTs is int) {
              sec = rawTs.toDouble();
            } else if (rawTs is double) {
              sec = rawTs;
            }
            final tsString = _formatTimestamp(sec);
            newTranscript.add(TranscriptItem(time: tsString, content: sentence));
          }
        }

        setState(() {
          _chatMessages = newChatList;
          _transcript = newTranscript;
          _sessionId = data['session_id'] ?? _sessionId;
        });
      } else {
        if (kDebugMode) {
          print('Error from ask server: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in _askServer: $e');
      }
    }
  }

  // Helper: Convert e.g. 127.86 -> "2:07"
  String _formatTimestamp(double seconds) {
    final s = seconds.floor() % 60;
    final m = (seconds.floor() ~/ 60) % 60;
    final h = (seconds.floor() ~/ 3600);
    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '${m.toString()}:${s.toString().padLeft(2, '0')}';
    }
  }

  // ------------------------------------------------------------------------
  // (C) Load/Play the Video (Local or YouTube)
  // ------------------------------------------------------------------------
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
      _webLocalVideoUrl = null;
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
        // 1) Upload to the server for transcript
        await _uploadVideoToServer(link);

        // 2) Extract YT ID and load in the YT Player
        final videoId = YoutubePlayerController.convertUrlToId(link);
        if (videoId == null) throw Exception("Invalid YouTube link");
        _youtubeController = YoutubePlayerController(
          params: const YoutubePlayerParams(showFullscreenButton: true),
        )..loadVideoById(videoId: videoId);

        setState(() {
          _videoReady = true;
          _isLoading = false;
        });
      } else {
        // Non-YouTube
        if (kIsWeb) {
          if (link.startsWith('blob:') || link.startsWith('file:')) {
            // Web local fallback
            setState(() {
              _webLocalVideoUrl = link;
              _videoReady = true;
              _isLoading = false;
            });
          } else if (link.startsWith('http')) {
            // Web network
            await _setupChewieNetwork(link);
          } else {
            throw Exception('Unsupported link on web: $link');
          }
        } else {
          // Mobile/desktop
          if (_isLocalFile(link)) {
            final filePath = link.startsWith('file://') ? link.substring(7) : link;
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

  Future<void> _pickLocalVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
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

  bool _isLocalFile(String link) {
    return link.startsWith("file://") || File(link).isAbsolute;
  }

  // ------------------------------------------------------------------------
  // (D) Seek Video from Transcript
  // ------------------------------------------------------------------------
  void _seekVideoToTime(String time) {
    // time is like "2:07" or "01:15:23"
    final parts = time.split(':').reversed.toList();
    int totalSeconds = 0;
    for (int i = 0; i < parts.length; i++) {
      final val = int.tryParse(parts[i]) ?? 0;
      totalSeconds += val * (60 ^ i); // 60^0=1, 60^1=60, 60^2=3600
    }

    if (_isYouTube && _youtubeController != null) {
      _youtubeController?.seekTo(seconds: totalSeconds.toDouble());
      _youtubeController?.playVideo();
    } else if (kIsWeb && _webLocalVideoUrl != null) {
      // Not implemented seeking for web local fallback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeking not implemented for web local fallback.')),
      );
    } else {
      _videoController?.seekTo(Duration(seconds: totalSeconds));
      _videoController?.play();
    }
  }

  // ------------------------------------------------------------------------
  // (E) Chat logic: user enters a question
  // ------------------------------------------------------------------------
  Future<void> _sendChatMessage() async {
    final userMessage = _chatController.text.trim();
    if (userMessage.isEmpty) return;

    // Clear dummy chat if it's the first real query
    if (_dummyChatActive) {
      setState(() {
        _chatMessages.clear();
        _dummyChatActive = false;
      });
    }

    // Show user message immediately
    setState(() {
      _chatMessages.add("User: $userMessage");
      _chatController.clear();
    });

    // Actually call the "ask" API
    await _askServer(userMessage);
  }

  // ------------------------------------------------------------------------
  // (F) Download Notes (PDF)
  // ------------------------------------------------------------------------
  Future<void> _downloadNotes() async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not established. Please load a session first.')),
      );
      return;
    }

    const apiUrl = 'http://127.0.0.1:5000/notes';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _sessionId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String notes = data['notes'] ?? '';

        // 1) Build PDF
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return [
                pw.Text(
                  'Lecture Notes',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  notes,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ];
            },
          ),
        );

        // 2) Save PDF to bytes
        final pdfBytes = await pdf.save();

        // 3) Download approach: web vs other
        if (kIsWeb) {
          // Use HTML anchor to download on web
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', 'notes.pdf')
            ..style.display = 'none';
          html.document.body!.append(anchor);

          // Click & remove
          anchor.click();
          anchor.remove(); // instead of removeChild

          html.Url.revokeObjectUrl(url);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notes download initiated')),
          );
        } else {
          // Mobile/Desktop
          final status = await Permission.storage.request();
          if (status.isGranted) {
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

            final filePath = '${directory.path}/notes.pdf';
            final file = File(filePath);
            await file.writeAsBytes(pdfBytes);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notes PDF saved')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission denied')),
              );
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('Error downloading notes: ${response.body}');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in _downloadNotes: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download notes')),
      );
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
                                  // If it's YouTube
                                  if (_isYouTube && _youtubeController != null) {
                                    return YoutubePlayer(
                                      controller: _youtubeController!,
                                      aspectRatio: 16 / 9,
                                    );
                                  }
                                  // Web local fallback
                                  if (kIsWeb && _webLocalVideoUrl != null) {
                                    return _LocalWebVideoPlayer(
                                      videoUrl: _webLocalVideoUrl!,
                                    );
                                  }
                                  // Otherwise, Chewie for local or network video
                                  if (_chewieController != null) {
                                    return AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: Chewie(
                                        controller: _chewieController!,
                                      ),
                                    );
                                  }
                                  // If we reach here, no player
                                  return const Center(child: Text('Video Error'));
                                }),
                              ),
                              const SizedBox(height: 8),
                              // Always show "Download Notes" if we have a loaded video
                              ElevatedButton(
                                onPressed: _downloadNotes,
                                child: const Text('Download Notes'),
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
                            // conversation
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
                                      hintText: "Ask a question...",
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
                              // Seek video to that timestamp
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

/// Fallback for local blob/data URLs on Flutter Web.
/// By default, video_player doesn't handle `file://` or `blob:` URLs.
class _LocalWebVideoPlayer extends StatefulWidget {
  final String videoUrl;
  // ignore: unused_element
  const _LocalWebVideoPlayer({super.key, required this.videoUrl});

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
        ..autoplay = true // Browsers often require muted to auto-play
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _elementId);
  }
}
