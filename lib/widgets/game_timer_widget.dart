import 'dart:async';
import 'package:flutter/material.dart';

class GameTimerWidget extends StatefulWidget {
  final int? timeLimitSeconds;
  final bool isGameActive;
  final int bonusSeconds;
  final VoidCallback? onTimeUp;
  final Function(String)? onTimeUpdate;

  const GameTimerWidget({
    Key? key,
    this.timeLimitSeconds,
    required this.isGameActive,
    this.bonusSeconds = 0,
    this.onTimeUp,
    this.onTimeUpdate,
  }) : super(key: key);

  @override
  State<GameTimerWidget> createState() => _GameTimerWidgetState();
}

class _GameTimerWidgetState extends State<GameTimerWidget> {
  late Timer _timer;
  int _elapsedSeconds = 0;
  String _formattedTime = "00:00";

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (widget.isGameActive) {
        setState(() {
          _elapsedSeconds++;
          _updateFormattedTime();
        });

        widget.onTimeUpdate?.call(_formattedTime);

        if (widget.timeLimitSeconds != null &&
            _elapsedSeconds >= (widget.timeLimitSeconds! + widget.bonusSeconds)) {
          timer.cancel();
          widget.onTimeUp?.call();
        }
      }
    });
  }

  void _updateFormattedTime() {
    if (widget.timeLimitSeconds != null) {
      final totalTime = widget.timeLimitSeconds! + widget.bonusSeconds;
      final remaining = totalTime - _elapsedSeconds;
      if (remaining <= 0) {
        _formattedTime = "00:00";
      } else {
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        _formattedTime = '$minutes:$seconds';
      }
    } else {
      final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      _formattedTime = '$minutes:$seconds';
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCountdown = widget.timeLimitSeconds != null;
    final totalTime = isCountdown ? (widget.timeLimitSeconds! + widget.bonusSeconds) : 0;
    final remaining = isCountdown ? totalTime - _elapsedSeconds : 0;
    final isLowTime = isCountdown && remaining <= 60; // Last minute warning

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCountdown ? Icons.hourglass_bottom : Icons.timer,
            color: isLowTime ? Colors.red : Colors.blue,
            size: 20,
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLowTime
                  ? Colors.red.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLowTime ? Colors.red : Colors.blue,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLowTime ? Colors.red : Colors.blue,
                  ),
                ),
                if (widget.bonusSeconds > 0) ...[
                  SizedBox(width: 4),
                  Text(
                    '+${widget.bonusSeconds}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),

    ],
      ),
    );
  }
}