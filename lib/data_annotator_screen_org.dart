import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:myan_annotator/utils.dart';

class DataAnnotatorScreen extends StatefulWidget {
  const DataAnnotatorScreen({super.key});

  @override
  State<DataAnnotatorScreen> createState() => _DataAnnotatorScreenState();
}

class _DataAnnotatorScreenState extends State<DataAnnotatorScreen> {
  late QuillController _quillController;
  final TextEditingController _originalController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Map<String, String> _dictionary = {};
  final List<Map<String, dynamic>> _history = [];
  final Set<String> _newlyAddedWords = {};

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
  }

  Future<void> loadDictionary() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString(encoding: const Utf8Codec());
        Map<String, dynamic> loadedDictionary = jsonDecode(content);
        setState(() {
          _dictionary.clear();
          _dictionary.addAll(
            loadedDictionary.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
          _applyHighlights(_quillController.document.toPlainText());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading file: $e')));
    }
  }

  /* void _applyHighlights(String text) {
    if (_isApplyingHighlights) return; // Prevent reentrant updates
    _isApplyingHighlights = true;

    _debouncedUpdate(() {
      try {
        if (text.isEmpty) {
          _quillController.document = Document()..insert(0, '\n');
          _isApplyingHighlights = false;
          return;
        }

        final currentSelection = _quillController.selection;
        List<String> syllables = syllableSplit(text);
        List<String> tokens = maximumMatching(syllables, _dictionary);
        Delta delta = Delta();
        int currentIndex = 0;

        for (String token in tokens) {
          int startIndex = text.indexOf(token, currentIndex);
          if (startIndex >= 0) {
            if (startIndex > currentIndex) {
              delta.insert(text.substring(currentIndex, startIndex));
            }
            delta.insert(token, {
              'background':
                  _dictionary.containsKey(token)
                      ? '#FFFF00'
                      : _newlyAddedWords.contains(token)
                      ? '#00FF00'
                      : null,
            });
            currentIndex = startIndex + token.length;
          }
        }
        if (currentIndex < text.length) {
          delta.insert(text.substring(currentIndex));
        }

        _quillController.document = Document.fromDelta(delta);
        _quillController.updateSelection(currentSelection, ChangeSource.local);
      } finally {
        _isApplyingHighlights = false;
      }
    });
  } */

  void _applyHighlights(String text) {
    List<String> syllables = syllableSplit(text);
    List<String> tokens = maximumMatching(syllables, _dictionary);
    Delta delta = Delta();
    int currentIndex = 0;

    for (String token in tokens) {
      int startIndex = text.indexOf(token, currentIndex);
      if (startIndex >= 0) {
        if (startIndex > currentIndex) {
          delta.insert(text.substring(currentIndex, startIndex));
        }
        delta.insert(token, {
          'background':
              _dictionary.containsKey(token)
                  ? '#FFFF00' // Yellow for dictionary words
                  : _newlyAddedWords.contains(token)
                  ? '#00FF00' // Green for newly added
                  : null,
        });
        currentIndex = startIndex + token.length;
      }
    }
    if (currentIndex < text.length) {
      delta.insert(text.substring(currentIndex));
    }

    _quillController.document = Document.fromDelta(delta);
  }

  Future<void> loadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString(encoding: const Utf8Codec());
        // _controller.text = content; // Replace content directly
        _originalController.text = content;
        _quillController.document = Document()..insert(0, content);
        _applyHighlights(content);
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading file: $e')));
    }
  }

  Future<void> saveDictionary() async {
    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Dictionary File',
        fileName: 'dictionary.json',
      );
      if (outputPath != null) {
        File file = File(outputPath);
        if (await file.exists()) {
          bool? shouldOverride = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('File Exists'),
                  content: const Text(
                    'The file already exists. Do you want to override it?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
          );
          if (shouldOverride != true) return; // Exit if user declines
        }
        String jsonContent = jsonEncode(_dictionary);
        await file.writeAsString(jsonContent, encoding: const Utf8Codec());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dictionary saved successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving dictionary: $e')));
    }
  }

  void annotateText(String tag) {
    final selection = _quillController.selection;
    if (selection.start != selection.end) {
      _history.add({
        'document': _quillController.document.toDelta(),
        'selection': TextSelection(
          baseOffset: selection.baseOffset,
          extentOffset: selection.extentOffset,
        ),
      });

      String selectedText = _quillController.document.getPlainText(
        selection.start,
        selection.end - selection.start,
      );

      if (!_dictionary.containsKey(selectedText)) {
        _dictionary[selectedText] = tag;
        _newlyAddedWords.add(selectedText);
        _applyHighlights(_quillController.document.toPlainText());
      }
      _quillController.moveCursorToPosition(selection.end);

      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select text to annotate')),
      );
    }
  }

  void undo() {
    if (_history.isNotEmpty) {
      final lastState = _history.removeLast();
      // _controller.text = lastState['text'];
      // _controller.selection = lastState['selection'];
      Document.fromDelta(lastState['document']);
      _quillController.updateSelection(
        lastState['selection'],
        ChangeSource.local,
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to undo')));
    }
  }

  /* void cleanData() {
    String cleanedText =
        _quillController.document
            .toPlainText()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('။', '။\n')
            .trim();
    String originalCleanedText =
        _originalController.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('။', '။\n')
            .trim();
    _quillController.document = Document()..insert(0, cleanedText);
    _originalController.text = originalCleanedText;
    _applyHighlights(cleanedText);
    setState(() {});
  } */

  Future<void> mergeData() async {
    try {
      String outputPath = 'reconstruction_dataset.csv';
      File file = File(outputPath);
      bool fileExists = await file.exists();

      // Split both text fields into lines
      List<String> tokenizedLines = _quillController.document
          .toPlainText()
          .split('\n');
      List<String> originalLines = _originalController.text.split('\n');

      // Ensure both have the same number of lines
      int maxLines = min(tokenizedLines.length, originalLines.length);
      List<List<String>> csvData = [
        ['tokenized', 'original'], // Header
        ...List.generate(
          maxLines,
          (index) => [
            tokenizedLines[index].trim(),
            originalLines[index].trim(),
          ],
        ),
      ];

      // Convert to CSV string
      String csvContent = const ListToCsvConverter().convert(csvData);

      // Write to file (create if not exists, overwrite if exists)
      if (fileExists) {
        // Optionally prompt user to overwrite (uncomment if needed)
        await file.writeAsString(csvContent, encoding: const Utf8Codec());
      } else {
        await file.writeAsString(csvContent, encoding: const Utf8Codec());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dataset merged and saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error merging data: $e')));
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _originalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Burmese Text Annotator')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Field Column
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: loadFile,
                            child: const Text('Load File'),
                          ),
                          const SizedBox(width: 10),
                          /* ElevatedButton(
                            onPressed: cleanData,
                            child: const Text('Clean Data'),
                          ),
                          const SizedBox(width: 10), */
                          ElevatedButton(
                            onPressed: loadDictionary,
                            child: const Text('Load Dict'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: saveDictionary,
                            child: const Text('Save Dict'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: mergeData,
                            child: const Text('Merge Data'),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => annotateText('root'),
                            child: const Text('Root'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => annotateText('particle'),
                            child: const Text('Particle'),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _originalController,
                      enabled: false, // Disable editing
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'Pyidaungsu',
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Original text...',
                      ),
                    ),
                  ),
                  // Existing Tokenized Text Field
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 1,
                    child: QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _focusNode,
                      config: QuillEditorConfig(
                        customStyles: DefaultStyles(
                          paragraph: DefaultTextBlockStyle(
                            const TextStyle(
                              fontFamily: 'Pyidaungsu',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(6, 0),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select text to annotate with root or particle.',
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            // Dictionary Canvas
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _dictionary.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text('${entry.key}: ${entry.value}'),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
