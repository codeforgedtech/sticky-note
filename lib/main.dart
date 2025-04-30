import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sticky_notes/supabase_config.dart';
import 'settings_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart'; // För datumformatering
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final Uuid uuid = Uuid();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize(); // Initialize Supabase
  runApp(Sticky());
  tz_data.initializeTimeZones();
  String title = 'Reminder'; // Define a title for the notification
  String body =
      'This is your scheduled notification.'; // Define the body content
  DateTime scheduledDate =
      DateTime.now().add(Duration(seconds: 10)); // Example scheduled date

  await flutterLocalNotificationsPlugin.zonedSchedule(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    tz.TZDateTime.from(scheduledDate, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'note_channel',
        'Note Reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}

class Sticky extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        hintColor: Colors.deepOrangeAccent,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> filteredNotes = [];
  TextEditingController searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedNotes = prefs.getStringList('notes');
    if (savedNotes != null) {
      setState(() {
        notes = savedNotes
            .map((note) => Map<String, dynamic>.from(json.decode(note)))
            .toList();
        filteredNotes = List.from(notes);
      });
      print('Notes loaded locally.');
    }
  }

  _saveNotes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Save notes to Supabase
      try {
        final response = await Supabase.instance.client.from('notes').upsert(
              notes
                  .map((note) => {
                        'user_id': user.id,
                        'title': note['title'],
                        'content': note['content'],
                        'color': note['color'],
                        'reminder_time': note['reminderTime'],
                      })
                  .toList(),
            );

        if (response != null && response is List) {
          // Successfully synced notes
          print('Notes synced to Supabase!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notes synced to the database!')),
          );
        } else {
          // Handle unexpected response
          print('Unexpected response from Supabase: $response');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unexpected response from Supabase.')),
          );
        }
      } catch (e) {
        // Handle exceptions
        print('Error syncing notes: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing notes: $e')),
        );
      }
    } else {
      print('User is not logged in. Saving notes locally.');
      // Save notes locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> savedNotes = notes.map((note) => json.encode(note)).toList();
      prefs.setStringList('notes', savedNotes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notes saved locally.')),
      );
    }
  }

  _saveNotesLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedNotes = notes.map((note) => json.encode(note)).toList();
    prefs.setStringList('notes', savedNotes);
    print('Notes saved locally.');
  }

  Future<void> _scheduleNotification(
      String title, String body, DateTime scheduledTime, int noteIndex) async {
    if (scheduledTime.isBefore(DateTime.now())) return; // Avoid past times

    await flutterLocalNotificationsPlugin.zonedSchedule(
      noteIndex, // Unique ID for the notification
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'note_channel',
          'Note Reminders',
          channelDescription: 'Reminders for notes',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    // Schedule a callback to turn the note grey after the notification
    Future.delayed(scheduledTime.difference(DateTime.now()), () {
      setState(() {
        notes[noteIndex]['color'] = Colors.grey.value; // Change to grey
        _saveNotes();
      });
    });
  }

  Future<void> _addNote() async {
    Map<String, dynamic>? newNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController = TextEditingController();
        TextEditingController contentController = TextEditingController();
        Color selectedColor = Colors.teal;
        DateTime? reminderTime;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Create a new note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.teal,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "Title",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        hintText: "Edit your note here",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Choose color:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _colorOption(Colors.teal, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.teal;
                          });
                        }),
                        _colorOption(Colors.green, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.green;
                          });
                        }),
                        _colorOption(Colors.blue, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.blue;
                          });
                        }),
                        _colorOption(Colors.pink, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.pink;
                          });
                        }),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Reminder:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: reminderTime != null
                              ? Text(
                                  'Reminder set: ${DateFormat('yyyy-MM-dd – kk:mm').format(reminderTime!)}',
                                  style: TextStyle(color: Colors.teal),
                                )
                              : Text(
                                  'Set a reminder',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14),
                                ),
                        ),
                        IconButton(
                          icon: Icon(Icons.access_alarm, color: Colors.teal),
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: reminderTime ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    reminderTime ?? DateTime.now()),
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  reminderTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'id': uuid.v4(), // Generate a unique ID for the note
                      'title': titleController.text,
                      'content': contentController.text,
                      'color': selectedColor.value,
                      'reminderTime': reminderTime?.toIso8601String(),
                    });
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newNote != null && newNote['title']!.isNotEmpty) {
      setState(() {
        notes.add(newNote);
        filteredNotes.add(newNote);
      });
      _saveNotesLocally(); // Save notes locally
    }
  }

  Widget _colorOption(Color color, Color selectedColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: 10),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selectedColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  _deleteNote(int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final noteId =
            notes[index]['id']; // Assuming each note has a unique 'id'
        final response = await Supabase.instance.client
            .from('notes')
            .delete()
            .eq('id', noteId)
            .eq('user_id',
                user.id) // Ensure the note belongs to the logged-in user
            .select(); // Ensure the response contains the deleted note(s)

        if (response != null && response.isNotEmpty) {
          setState(() {
            notes.removeAt(index);
            filteredNotes.removeAt(index);
          });
          print('Note deleted successfully!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note deleted successfully!')),
          );
        } else {
          print('Error deleting note: Response is null or empty');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error deleting note: Response is null or empty')),
          );
        }
      } catch (e) {
        print('Error deleting note: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to delete notes.')),
      );
    }
  }

  _editNote(int index) async {
    Map<String, dynamic>? editedNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController =
            TextEditingController(text: notes[index]['title']);
        TextEditingController contentController =
            TextEditingController(text: notes[index]['content']);
        Color selectedColor = Color(notes[index]['color']);
        DateTime? reminderTime = notes[index]['reminderTime'] != null
            ? DateTime.tryParse(notes[index]['reminderTime'])
            : null;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Edit note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.teal,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: "Title",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        prefixIcon: Icon(Icons.title, color: Colors.teal),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        hintText: "Edit your note here",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        prefixIcon: Icon(Icons.edit, color: Colors.teal),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Choose color:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _colorOption(Colors.teal, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.teal;
                          });
                        }),
                        _colorOption(Colors.green, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.green;
                          });
                        }),
                        _colorOption(Colors.blue, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.blue;
                          });
                        }),
                        _colorOption(Colors.pink, selectedColor, () {
                          setState(() {
                            selectedColor = Colors.pink;
                          });
                        }),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Reminder:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: reminderTime != null
                              ? Text(
                                  'Reminder set: ${DateFormat('yyyy-MM-dd – kk:mm').format(reminderTime!)}',
                                  style: TextStyle(color: Colors.teal),
                                )
                              : Text(
                                  'Set a reminder',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14),
                                ),
                        ),
                        IconButton(
                          icon: Icon(Icons.access_alarm, color: Colors.teal),
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: reminderTime ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (pickedDate != null) {
                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    reminderTime ?? DateTime.now()),
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  reminderTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'title': titleController.text,
                      'content': contentController.text,
                      'color': selectedColor.value,
                      'reminderTime': reminderTime?.toIso8601String(),
                    });
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (editedNote != null && editedNote['title']!.isNotEmpty) {
      setState(() {
        notes[index] = editedNote;
        filteredNotes[index] = editedNote;
      });
      _saveNotes();

      // 🛎️ Schemalägg notis om tid sattes
      if (editedNote['reminderTime'] != null) {
        await _scheduleNotification(
          editedNote['title'],
          editedNote['content'],
          DateTime.parse(editedNote['reminderTime']),
          index,
        );
      }
    }
  }

  _filterNotes() {
    setState(() {
      filteredNotes = notes
          .where((note) =>
              note['title']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              note['content']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()))
          .toList();
    });
  }

  _syncToDatabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client.from('notes').upsert(
              notes
                  .map((note) => {
                        'id': note['id'], // Ensure 'id' is included
                        'user_id': user.id,
                        'title': note['title'],
                        'content': note['content'],
                        'color': note['color'],
                        'reminder_time': note['reminderTime'],
                      })
                  .toList(),
            );

        if (response != null && response is List) {
          print('Notes synced to Supabase!');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notes synced to the database!')),
          );
        } else {
          print('Error syncing notes: Response is null or unexpected');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error syncing notes: Response is null or unexpected')),
          );
        }
      } catch (e) {
        print('Error syncing notes: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing notes: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in to sync notes.')),
      );
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_filterNotes);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Sticky Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.teal,
          elevation: 4,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.exit_to_app, color: Colors.white),
              onPressed: () {
                _showExitDialog();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Search notes...',
                  prefixIcon: Icon(Icons.search, color: Colors.teal),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    Color noteColor = Color(filteredNotes[index]['color']);
                    DateTime? reminderTime =
                        filteredNotes[index]['reminderTime'] != null
                            ? DateTime.tryParse(
                                filteredNotes[index]['reminderTime'])
                            : null;
                    String reminderText = reminderTime != null
                        ? 'Reminder set for: ${reminderTime.toLocal()}'
                            .split('.')[0]
                        : 'No reminder set';

                    return GestureDetector(
                        onTap: () async {
                          // Open the edit dialog when tapping on a note
                          await _editNote(index);
                        },
                        child: Card(
                          color: noteColor,
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        filteredNotes[index]['title'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        filteredNotes[index]['content'],
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          reminderTime != null
                                              ? Icon(Icons.access_alarm,
                                                  color: Colors.black)
                                              : Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Text(
                                                      'No reminder set',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                          SizedBox(width: 5),
                                          Text(
                                            reminderTime != null
                                                ? DateFormat('yy-MM-dd – kk:mm')
                                                    .format(reminderTime)
                                                : '',
                                            style: TextStyle(
                                              color: reminderTime != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                              fontSize: 12,
                                              decoration: reminderTime == null
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.white),
                                  onPressed: () {
                                    _deleteNote(index);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ));
                  }),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });

            if (index == 0) {
              _addNote();
            } else if (index == 1) {
              _showUserDialog(context);
            } else if (index == 2) {
              _syncToDatabase(); // Sync notes
            } else if (index == 3) {
              _showInstructions();
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.plus,
                size: 30,
              ),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.user,
                size: 30,
              ),
              label: 'User',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.sync,
                size: 30,
              ),
              label: 'Sync',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.help_outline,
                size: 30,
              ),
              label: 'Help',
            ),
          ],
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 5,
        ));
  }

  _showInstructions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Instructions'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Sticky Notes App!\n\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'How to use the app:\n'
                  '1. To create a new note, click the "+" icon at the bottom of the screen.\n'
                  '2. Enter a title and content for your note. You can also choose a color for your note.\n'
                  '3. Your note will be saved locally on your device and will appear in the main screen.\n\n'
                  'Search Notes:\n'
                  'You can search for your notes by typing keywords in the search bar at the top of the screen.\n\n'
                  'Delete or Edit Notes:\n'
                  'To delete a note, click the trash icon on the note card.\n'
                  'To edit a note, tap the note and update the title, content, or color.\n\n'
                  'Sync to Database:\n'
                  'To sync your notes to the cloud, tap the "Sync" icon in the bottom navigation bar. \n'
                  'Note: You must be logged in to sync notes to the database.\n\n'
                  'Enjoy using Sticky Notes!',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Exit App'),
          content: Text('Do you want to sync your notes before exiting?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _syncToDatabase(); // Sync notes
                Future.delayed(Duration(milliseconds: 500), () {
                  Navigator.of(context).pop(); // Exit the app
                });
              },
              child: Text('Sync & Exit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pop(); // Exit the app
              },
              child: Text('Exit Without Syncing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

extension on PostgrestList {
  get error => null;

  Iterable? get data => null;
}

_showUserDialog(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                user != null ? Icons.account_circle : Icons.login,
                size: 60,
                color: user != null ? Colors.teal : Colors.grey,
              ),
              SizedBox(height: 10),
              Text(
                user != null ? 'Welcome, ${user.email}!' : 'Log in',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                user != null
                    ? 'You are logged in as ${user.email}.'
                    : 'To sync your notes, please log in first.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (user != null) {
                    // Log out
                    await Supabase.instance.client.auth.signOut();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logged out successfully!')),
                    );
                  } else {
                    // Navigate to login page
                    Navigator.of(context).pop();
                    _navigateToLoginPage(context);
                  }
                },
                child: Text(user != null ? 'Log out' : 'Log in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      user != null ? Colors.redAccent : Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

_navigateToLoginPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LoginPage(
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final VoidCallback onClose;

  LoginPage({required this.onClose});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      if (isLogin) {
        // Login
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in successfully!')),
        );
      } else {
        // Register
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created successfully!')),
        );
      }
      widget.onClose(); // Close the dialog
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLogin ? 'Login' : 'Register',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email, color: Colors.teal),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: Colors.teal),
                    ),
                    obscureText: true,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isLogin ? 'Login' : 'Sign Up',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isLogin = !isLogin;
                      });
                    },
                    child: Text(
                      isLogin
                          ? "Don't have an account? Register"
                          : "Already have an account? Login",
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
