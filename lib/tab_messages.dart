import 'package:flutter/material.dart';
import 'tabs.dart';
import 'dart:developer' as developer;

class Message {
  final bool tx;
  final String name;
  final String contents;
  Message({required this.tx, required this.name, required this.contents});
  // Factory constructor to create a Message from a Map<String, Object>
  factory Message.fromMap(Map<dynamic, dynamic> map) {
    developer.log("got Message map: $map");
    return Message(
      tx: map['tx'] as bool? ?? false,
      name: map['name'] as String? ?? "",
      contents: map['contents'] as String? ?? "",
    );
  }
}

Widget buildTabMsg(BuildContext context, TabsState state) {
  WidgetsBinding.instance.addPostFrameCallback((_) => state.scrollToBottom());
  return StatefulBuilder(
    builder: (context, setState) {
      return Column(
        children: [
          // Dropdown filter row
          Row(
            children: [
              const Icon(Icons.search),
              // isTx Filter
              DropdownButton<bool?>(
                hint: const Text('Direction filter'),
                value: state.isTxFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Direction')),
                  DropdownMenuItem(value: false, child: Text('Rx')),
                  DropdownMenuItem(value: true, child: Text('Tx')),
                ],
                onChanged: (value) {
                  setState(() {
                    state.isTxFilter = value;
                    state.filterMessages();
                  });
                },
              ),
              // Name Filter
              DropdownButton<String?>(
                hint: const Text('Name filter'),
                value: state.nameFilter,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Name')),
                  ...state.uniqueNames.map((name) {
                    return DropdownMenuItem(value: name, child: Text(name));
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    state.nameFilter = value;
                    state.filterMessages();
                  });
                },
              ),
              // Contents Filter
              Expanded(
                child: TextField(
                  controller: state.contentsController,
                  decoration: const InputDecoration(
                    hintText: 'Contents',
                  ),
                  onChanged: (query) {
                    setState(() {
                      state.filterMessages();
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
              const Text('Autoscroll'),
              Checkbox(
                value: state.autoScroll,
                onChanged: (bool? value) {
                  setState(() {
                    state.autoScroll = value ?? true;
                  });
                },
              ),
            ],
          ),
          // Messages list
          Expanded(
            child: Scrollbar(
                controller: state.scrollController,
                thumbVisibility:
                    true, // Optional: Always show the scrollbar thumb
                child: ListView.builder(
                  key: const ValueKey('msgList'),
                  itemCount: state.filteredMessages.length,
                  controller: state.scrollController,
                  itemBuilder: (context, index) {
                    final message = state.filteredMessages[index];
                    return ListTile(
                      key: ValueKey(state.filteredMessages[index].name +
                          state.filteredMessages[index]
                              .contents), // Unique key per item
                      title: Text(message.name),
                      subtitle: Text(message.contents),
                      onTap: () {
                        setState(() {
                          state.autoScroll = false;
                        });
                        state.showDialogMessage(message);
                      },
                    );
                  },
                )),
          ),
        ],
      );
    },
  );
}
