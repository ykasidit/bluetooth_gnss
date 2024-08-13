import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'tabs.dart';

class Message {
  final bool tx;
  final String name;
  final String contents;
  Message({required this.tx, required this.name, required this.contents});
  // Factory constructor to create a Message from a Map<String, Object>
  factory Message.fromMap(Map<dynamic, dynamic> map) {
    print("got Message map: $map");
    return Message(
      tx: map['tx'] as bool,
      name: map['name'] as String,
      contents: map['contents'] as String,
    );
  }
}

bool autoScroll = true;

Widget BuildTabMsg(BuildContext context, TabsState state) {
  final TextEditingController contentsController = TextEditingController();
  List<Message> filteredMessages = state.msgList;

  // Dropdown filter variables
  bool? isTxFilter;
  String? nameFilter;
  List<String> uniqueNames = state.msgList.map((e) => e.name).toSet().toList();

  void filterMessages() {
    filteredMessages = state.msgList.where((message) {
      final matchesIsTx = isTxFilter == null || message.tx == isTxFilter;
      final matchesName = nameFilter == null || message.name == nameFilter;
      final matchesContents = message.contents.toLowerCase().contains(contentsController.text.toLowerCase());

      return matchesIsTx && matchesName && matchesContents;
    }).toList();
  }

  void showDialogMessage(Message message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(message.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentsController,
                    decoration: InputDecoration(
                      hintText: 'Search in message...',
                    ),
                    onChanged: (query) {
                      // Implement search and highlight within the dialog
                    },
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(message.contents),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {
                    // Implement share functionality
                  },
                ),
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  ScrollController _scrollController = ScrollController();
  _scrollToBottom() {
    if (autoScroll && filteredMessages.length > 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

  return StatefulBuilder(
    builder: (context, setState) {

      return Column(
        children: [
          // Dropdown filter row
          Row(
            children: [
              Icon(
                Icons.search
              ),
              // isTx Filter
              DropdownButton<bool?>(
                hint: Text('Direction filter'),
                value: isTxFilter,
                items: [
                  DropdownMenuItem(value: null, child: Text('Direction')),
                  DropdownMenuItem(value: true, child: Text('Rx')),
                  DropdownMenuItem(value: false, child: Text('Tx')),
                ],
                onChanged: (value) {
                  setState(() {
                    isTxFilter = value;
                    filterMessages();
                  });
                },
              ),
              // Name Filter
              DropdownButton<String?>(
                hint: Text('Name filter'),
                value: nameFilter,
                items: [
                  DropdownMenuItem(value: null, child: Text('Name')),
                  ...uniqueNames.map((name) {
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    nameFilter = value;
                    filterMessages();
                  });
                },
              ),
              // Contents Filter
              Expanded(
                child: TextField(
                  controller: contentsController,
                  decoration: InputDecoration(
                    hintText: 'Contents',
                  ),
                  onChanged: (query) {
                    setState(() {
                      filterMessages();
                    });
                  },
                ),
              ),
            ],
          ),
          // Autoscroll checkbox
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Autoscroll'),
              Checkbox(
                value: autoScroll,
                onChanged: (bool? value) {
                  setState(() {
                    autoScroll = value ?? true;
                  });
                },
              ),
            ],
          ),
          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: filteredMessages.length,
              controller: _scrollController,
              itemBuilder: (context, index) {
                final message = filteredMessages[index];
                return ListTile(
                  title: Text(message.name),
                  subtitle: Text(message.contents),
                  onTap: () {
                    setState(() {
                      autoScroll = false;
                    });
                    showDialogMessage(message);
                  },
                );
              },
            ),
          ),
        ],
      );
    },
  );
}