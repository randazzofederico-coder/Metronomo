import 'package:flutter/material.dart';


import 'package:native_audio_engine/soundtouch_processor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _processor = SoundTouchProcessor();
  String _status = 'Idle';

  @override
  void dispose() {
    _processor.dispose();
    super.dispose();
  }

  void _testProcessor() {
    setState(() {
      _status = 'Testing...';
    });
    
    try {
      _processor.setChannels(2);
      _processor.setSampleRate(44100);
      _processor.setTempo(1.5);
      _processor.setPitch(1.0);
      
      // Simulate processing
      final input = List.generate(1000, (index) => (index % 100) / 100.0);
      final output = _processor.process(input, 2);
      
      setState(() {
        _status = 'Success! Processed ${input.length} samples -> ${output.length} samples.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SoundTouch Native Test'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testProcessor,
                child: const Text('Run SoundTouch Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
