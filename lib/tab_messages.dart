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

Widget BuildTabMsg(BuildContext context, TabsState state) {
  WidgetsBinding.instance.addPostFrameCallback((_) => state.scrollToBottom());
  return StatefulBuilder(
    builder: (context, setState) {
      return Column(
        children: [
          // Dropdown filter row
          Row(
            children: [
              Icon(Icons.search),
              // isTx Filter
              DropdownButton<bool?>(
                hint: Text('Direction filter'),
                value: state.isTxFilter,
                items: [
                  DropdownMenuItem(value: null, child: Text('Name')),
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
                hint: Text('Name filter'),
                value: state.nameFilter,
                items: [
                  DropdownMenuItem(value: null, child: Text('Name')),
                  ...state.uniqueNames.map((name) {
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
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
                  decoration: InputDecoration(
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
              Text('Autoscroll'),
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
                  key: ValueKey('msgList'),
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
