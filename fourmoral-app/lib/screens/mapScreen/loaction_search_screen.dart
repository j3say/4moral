import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fourmoral/screens/mapScreen/navigation_search.dart';
import 'package:uuid/uuid.dart';

class LocationSearchScreen extends StatefulWidget {
  final title;
  final StreamSink<PlaceDetail>? sink;

  const LocationSearchScreen({super.key, required this.title, this.sink});

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _controller = TextEditingController();
  // final sessionToken = Uuid().v4();
  final provider = PlaceApiProvider(const Uuid().v4());
  List<Suggestion> suggestion = [];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  iconSize: 32,
                  padding: const EdgeInsets.only(left: 16, top: 8),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
                  child:
                      Text(widget.title, style: const TextStyle(fontSize: 22)),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(left: 18, top: 8, right: 18),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.start,
                autocorrect: false,
                onChanged: (value) async {
                  if (value.length > 1) {
                    suggestion = await provider.fetchSuggestions(value);
                  } else {
                    suggestion.clear();
                  }
                  setState(() {});
                },
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  icon: Container(
                    margin: const EdgeInsets.only(left: 12),
                    width: 32,
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  hintText: "Enter location",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemBuilder: (context, index) => ListTile(
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          (suggestion[index]).title,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          (suggestion[index]).description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ],
                  ),
                  leading: Container(
                    child: const Icon(
                      Icons.place_rounded,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  onTap: () async {
                    final placeDetail = await provider
                        .getPlaceDetailFromId(suggestion[index].placeId);
                    widget.sink?.add(placeDetail);
                    Navigator.pop(context);
                  },
                ),
                itemCount: suggestion.length,
              ),
            )
          ],
        ),
      ),
    );
  }
}
