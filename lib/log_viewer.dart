import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_gnss/channels.dart';
import 'package:bluetooth_gnss/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xterm/xterm.dart';

class LogViewerXtermPage extends StatefulWidget {
  final String filePath;
  final Duration pollInterval;

  const LogViewerXtermPage({
    super.key,
    required this.filePath,
    this.pollInterval = const Duration(milliseconds: 500),
  });

  @override
  State<LogViewerXtermPage> createState() => _LogViewerXtermPageState();
}

class _LogViewerXtermPageState extends State<LogViewerXtermPage> {
  late Terminal terminal;
  late TerminalController terminalController;
  final ScrollController _scrollController = ScrollController();

  File? _file;
  RandomAccessFile? _raf;
  Timer? _timer;

  int _pos = 0;

  String _search = "";
  bool _filterOnly = false;
  bool _follow = true;

  final List<String> _allLines = [];
  List<String> _visibleLines = [];

  static const int maxLines = 10000;

  void addLine(String line) {
    if (_allLines.length >= maxLines) {
      _allLines.removeAt(0); // remove oldest
    }
    _allLines.add(line);
    setState(() {});
  }


  @override
  void initState() {
    super.initState();

    terminal = Terminal(maxLines: maxLines);
    terminal.setLineFeedMode(true); // "\n" = newline + return
    terminalController = TerminalController();

    _file = File(widget.filePath);
    _initFile();

    // Poll selection every 300ms to update Copy button state
    Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initFile() async {
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
    }

    _raf = await _file!.open();

    final len = await _file!.length();
    _pos = len;

    _timer = Timer.periodic(widget.pollInterval, (_) => _pollAppend());
  }

  Future<void> _pollAppend() async {
    final len = await _file!.length();
    if (len <= _pos) return;

    final readLen = len - _pos;
    await _raf!.setPosition(_pos);
    final bytes = await _raf!.read(readLen);
    _pos = len;

    final chunk = utf8.decode(bytes, allowMalformed: true);
    final lines = chunk.split('\n');

    for (var raw in lines) {
      if (raw.trim().isEmpty) continue;

      final line = raw;
      addLine(line);

      if (_lineMatches(line)) {
        _visibleLines.add(line);
        if (_follow) {
          terminal.write(_highlight(line) + '\n');
        }
      }
    }
  }

  bool _lineMatches(String line) {
    if (!_filterOnly) return true;
    if (_search.isEmpty) return false;
    return line.toLowerCase().contains(_search.toLowerCase());
  }

  String _highlight(String line) {
    if (_search.isEmpty) return line;

    final lower = line.toLowerCase();
    final q = _search.toLowerCase();
    int start = 0;
    final buf = StringBuffer();

    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        buf.write(line.substring(start));
        break;
      }

      buf.write(line.substring(start, idx));
      buf.write('\x1B[43;30m');
      buf.write(line.substring(idx, idx + _search.length));
      buf.write('\x1B[0m');

      start = idx + _search.length;
    }

    return buf.toString();
  }

  void _rebuildVisible() {
    terminal.write('\x1B[2J\x1B[H'); // clear
    _visibleLines = [];

    for (var line in _allLines) {
      if (_lineMatches(line)) {
        _visibleLines.add(line);
        terminal.write(_highlight(line) + '\n');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _raf?.close();
    super.dispose();
  }

  Future<void> _copySelection() async {
    final sel = terminalController.selection;
    if (sel == null) return;

    final text = terminal.buffer.getText(sel);
    await Clipboard.setData(ClipboardData(text: text));
    terminalController.clearSelection();
  }

  /*Future<void> _shareSelection() async {
    final sel = terminalController.selection;
    if (sel == null) return;

    final text = terminal.buffer.getText(sel);
    final temp = File("${widget.filePath}.selection.txt");
    await temp.writeAsString(text);

    await Share.shareXFiles([XFile(temp.path)]);
  }*/

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)]);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = terminalController.selection != null;

    return Column(
      children: [
        // ---------- CONTROL BAR ----------
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              // SEARCH BOX
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: "Search",
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    _search = v;
                    _rebuildVisible();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 6),

              // FILTER
              Column(
                children: [
                  Text("Filter",style: Theme.of(context).textTheme.bodySmall),
                  Switch(
                    value: _filterOnly,
                    onChanged: (v) {
                      _filterOnly = v;
                      _rebuildVisible();
                      setState(() {});
                    },
                  ),
                ],
              ),

              // FOLLOW
              Column(
                children: [
                  Text("Follow", style: Theme.of(context).textTheme.bodySmall),
                  Switch(
                    value: _follow,
                    onChanged: (v) {
                      setState(() => _follow = v);
                      if (v) {
                        _scrollToBottom();
                      }
                    },
                  ),
                ],
              ),

              // COPY selection
              IconButton(
                icon: Icon(Icons.copy,
                    color: hasSelection ? Colors.blueAccent : Colors.grey),
                onPressed: hasSelection ? _copySelection : null,
                tooltip: "Copy selection",
              ),

              /*// SHARE selection
              IconButton(
                icon: Icon(Icons.share,
                    color: hasSelection ? Colors.blueAccent : Colors.grey),
                onPressed: hasSelection ? _shareSelection : null,
                tooltip: "Share selection",
              ),
               */
              // SHARE file
              IconButton(
                icon: const Icon(Icons.file_present),
                onPressed: _shareFile,
                tooltip: "Share whole trace file",
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: "Clear trace file",
                onPressed: () async {
                  bool ret = await clearTraceFile();
                  await toast("Clear trace file ${ret?'success':'failed'}");
                  if (ret) {
                    _pos = 0;
                    _allLines.clear();
                    _follow = true;
                    _rebuildVisible();
                    setState(() {});
                  }
                }
              ),
            ],
          ),
        ),

        // ---------- TERMINAL ----------
        Expanded(
          child: TerminalView(
            terminal,
            controller: terminalController,
            autofocus: false,
            backgroundOpacity: 1.0,
            textStyle: TerminalStyle.fromTextStyle(TextStyle(fontSize: 10)),
            readOnly: true,
            scrollController: _scrollController,
            // Desktop right-click = copy/paste like official example
            onSecondaryTapDown: (details, cell) async {
              final selection = terminalController.selection;
              if (selection != null) {
                final text = terminal.buffer.getText(selection);
                terminalController.clearSelection();
                await Clipboard.setData(ClipboardData(text: text));
              } else {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  terminal.paste(data!.text!);
                }
              }
            },
          ),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    // 3. Ensure the scroll happens after the new content has been built and sized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        // Use jumpTo for instant scrolling:
        // _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }
}
