import 'dart:async';

import 'package:flutter/material.dart';

const appVersion = 'v1.3';

/*
v2.0
Saved data to cloud.

v1.3
Stretch goal table header to match Actual table header.
Bold first lap of goal table.
Goal table should redraw if race distance or lap length are changed.
Reset button should not clear goal table.
Reset button should clear calculated pace lists.
Save code to GitHub.

v1.2
Add new pace calculation.
Calculate goal splits when goal time is set, rather than when play is pressed.
Formatting the seconds dropdown in goal time.
Check timer accuracy.

v1.1
Add milliseconds to timer.
Make stop and plus lap buttons bigger.
Fix race distance and lap distance dropdowns.
Clear split table on reset.
Commented out nudge buttons.
Added lap time clock.
Disabled play after play is pressed; enabled play after stop is pressed.

v1.0
Initial release. Timer, nudge timer +/-, start/stop/reset, add/remove laps, pace, split table.
*/

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPacer',
      theme: ThemeData(
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Gilmore Pacer $appVersion'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  static const int defaultRaceDistance = 1600;
  static const int defaultLapLength = 200;

  int raceDistance = defaultRaceDistance;
  int lapLength = defaultLapLength;

  int totalMilliseconds = 0;
  int thisLapMilliseconds = 0;

  int previousLapMilliseconds = 0;
  int numLaps = 0;
  int previousLap = -1;
  int previousNewLap = -1;
  String calculatedPace = '0:00';
  String calculatedNewPace = '0:00';
  List<String> calculatedPaces = [];
  List<String> calculatedNewPaces = [];
  double currentPace = 0.0;
  double currentNewPace = 0.0;
  int goalTimeMinutes = 0;
  int goalTimeSeconds = 0;

  final raceDistances = ['400', '600', '800', '1000', '1600', '3200'];
  final lapLengths = ['100', '130', '150', '200', '300', '400'];
  List<int> lapSplits = [];
  List<int> goalSplits = [];

  Timer? _timer;
  // Stopwatch stopwatch = Stopwatch();
  int savedStopwatchMilliseconds = 0;
  int diff = 0;
  bool _startButtonDisabled = false;
  bool _lapButtonDisabled = true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        title: Text(widget.title),
      ),
      body: Center(
        child: Container(
          height: 650,
          width: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Colors.amberAccent,
          ),
          padding: const EdgeInsets.all(50),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //Race distance dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    //Race
                    Column(
                      children: [
                        const Text(
                            'Race:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            DropdownButton(
                              value: raceDistance.toString(),
                              items: raceDistances.map((String value) {
                                return DropdownMenuItem(
                                  value: value,
                                  child: Text(value, style: const TextStyle(fontSize: 24)),
                                );
                              }).toList(),
                              onChanged: (s) {
                                setState(() {
                                  raceDistance = int.parse(s!);
                                  calculateGoalSplits();
                                });
                              },
                              icon: const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    //Lap
                    Column(
                      children: [
                        const Text(
                            'Lap:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        DropdownButton(
                          value: lapLength.toString(),
                          items: lapLengths.map((String value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text(value, style: const TextStyle(fontSize: 24)),
                            );
                          }).toList(),
                          onChanged: (s) {
                            setState(() {
                              lapLength = int.parse(s!);
                              calculateGoalSplits();
                            });
                          },
                          icon: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(width: 30),
                    //Goal
                    Column(
                      children: [
                        const Text(
                            'Goal:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            DropdownButton(
                              value: goalTimeMinutes,
                              items: [for (var i = 0; i < 60; i++) i].map((int value) {
                                return DropdownMenuItem(
                                  value: value,
                                  child: Text('$value', style: const TextStyle(fontSize: 24)),
                                );
                              }).toList(),
                              onChanged: (i) {
                                setState(() {
                                  goalTimeMinutes = i!;
                                  calculateGoalSplits();
                                });
                              },
                              icon: const SizedBox.shrink(),
                            ),
                            const Text(':', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            DropdownButton(
                              value: goalTimeSeconds,
                              items: [for (var i = 0; i < 60; i++) i].map((int value) {
                                return DropdownMenuItem(
                                  value: value,
                                  child: Text(value.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 24)),
                                );
                              }).toList(),
                              onChanged: (i) {
                                setState(() {
                                  goalTimeSeconds = i!;
                                  calculateGoalSplits();
                                });
                              },
                              icon: const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                //Clock and nudge buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                            formatMilliseconds(totalMilliseconds),
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  totalMilliseconds -= 1000;
                                  thisLapMilliseconds -= 1000;
                                });
                              },
                              icon: const Icon(Icons.fast_rewind),
                            ),
                            Text(
                                formatMilliseconds(thisLapMilliseconds),
                                style: const TextStyle(
                                  fontSize: 24,
                                )
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  totalMilliseconds += 1000;
                                  thisLapMilliseconds += 1000;
                                });
                              },
                              icon: const Icon(Icons.fast_forward),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                //Start, Stop, Reset buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _startButtonDisabled ? Colors.grey : Colors.green,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: _startButtonDisabled ? null : () {
                          _timer?.cancel();
                          // stopwatch.reset();
                          // stopwatch.start();
                          savedStopwatchMilliseconds = DateTime.now().millisecondsSinceEpoch;
                          _timer = Timer.periodic(
                            const Duration(milliseconds: 10), (timer) {
                              setState(() {
                                diff = DateTime.now().millisecondsSinceEpoch - savedStopwatchMilliseconds;
                                savedStopwatchMilliseconds = DateTime.now().millisecondsSinceEpoch;
                                totalMilliseconds += diff;
                                thisLapMilliseconds += diff;
                                // totalMilliseconds = stopwatch.elapsedMilliseconds;
                                // thisLapMilliseconds = stopwatch.elapsedMilliseconds - previousLapMilliseconds;
                              });
                            }
                          );
                          _startButtonDisabled = true;
                          _lapButtonDisabled = false;
                        },
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        //color: Colors.red,//Should be driven off of lap button
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _timer?.cancel();
                          // stopwatch.stop();
                          setState(() {
                            _startButtonDisabled = false;
                            _lapButtonDisabled = true;
                          });
                        },
                        icon: const Icon(Icons.stop),
                      ),
                    ),
                    const SizedBox(width: 30),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: () {
                          _timer?.cancel();
                          // stopwatch.reset();
                          setState(() {
                            totalMilliseconds = 0;
                            thisLapMilliseconds = 0;
                            previousLapMilliseconds = 0;
                            numLaps = 0;
                            lapSplits.clear();
                            // goalSplits.clear();
                            calculatedPaces.clear();
                            calculatedNewPaces.clear();
                            _startButtonDisabled = false;
                            _lapButtonDisabled = true;
                          });
                        },
                        icon: const Icon(Icons.replay),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                //Lap
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: _lapButtonDisabled ? null : () {
                          setState(() {
                            if(numLaps > 0) numLaps--;
                            lapSplits.removeLast();
                            calculatedPaces.removeLast();
                            calculatedNewPaces.removeLast();
                          });
                        },
                        icon: const Icon(Icons.remove),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        const Text('Lap:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            Text(
                              '$numLaps',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              )
                            ),
                            Text('/${raceDistance ~/ lapLength}'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _lapButtonDisabled ? Colors.grey : Colors.blue,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: IconButton(
                        onPressed: _lapButtonDisabled ? null : () {
                          setState(() {
                            numLaps++;

                            if(numLaps >= raceDistance ~/ lapLength) {
                              _timer?.cancel();
                              // stopwatch.stop();
                              _startButtonDisabled = false;
                              _lapButtonDisabled = true;
                            }

                            lapSplits.add(totalMilliseconds);

                            calculatedPace = calculatePace(totalMilliseconds, lapLength, numLaps, raceDistance);
                            calculatedPaces.add(calculatedPace);
                            calculatedNewPace = calculateNewPace(totalMilliseconds, lapLength, numLaps, raceDistance);
                            calculatedNewPaces.add(calculatedNewPace);

                            thisLapMilliseconds = 0;
                            previousLapMilliseconds = totalMilliseconds;
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                //Pace
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const Text('Pace:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            Text(
                              calculatedPace,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              )
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 70),
                    Column(
                      children: [
                        const Text('New Pace:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Row(
                          children: [
                            Text(
                                calculatedNewPace,
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                )
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                //Split tables
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Goal
                    Column(
                      children: [
                        const Text('Goal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Table(
                          border: TableBorder.all(),
                          columnWidths: const {
                            0: FixedColumnWidth(75),
                          },
                          children: [
                            const TableRow(
                              children: [
                                Center(child: Text('Split\n')),
                              ],
                            ),
                            for(int i = 0; i < goalSplits.length; i++)
                              TableRow(
                                children: [
                                  if(i == 0)
                                    Center(child: Text('${i+1}. ${formatMilliseconds(goalSplits[i])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  if(i > 0)
                                    Center(child: Text('${i+1}. ${formatMilliseconds(goalSplits[i])}')),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 1),
                    //Actual
                    Column(
                      children: [
                        const Text('Actual',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            )
                        ),
                        Table(
                          border: TableBorder.all(),
                          columnWidths: const {
                            0: FixedColumnWidth(70),
                            1: FixedColumnWidth(60),
                            2: FixedColumnWidth(45),
                            3: FixedColumnWidth(45),
                          },
                          children: [
                            const TableRow(
                              children: [
                                Center(child: Text('Lap')),
                                Center(child: Text('Split')),
                                Center(child: Text('Pace')),
                                Center(child: Text('New Pace')),
                              ],
                            ),
                            for(int i = 0; i < lapSplits.length; i++)
                              TableRow(
                                children: [
                                  Center(child: Text('${i+1}. ${calculateLapTime(i)}')),
                                  Center(child: Text(formatMilliseconds(lapSplits[i]))),
                                  Center(child: Text(calculatedPaces[i])),
                                  Center(child: Text(calculatedNewPaces[i])),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String formatMilliseconds(int totalMilliseconds) {
    int minutes = totalMilliseconds ~/ 60000;
    int seconds = (totalMilliseconds % 60000) ~/ 1000;
    int milliseconds = totalMilliseconds % 1000 ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}:${milliseconds.toString().padLeft(2, '0')}';
  }

  String calculatePace(int totalMilliseconds, int lapLength, int numLaps, int raceDistance) {
    // print('calculatePace1: $totalMilliseconds, $lapLength, $numLaps, $raceDistance');

    if(totalMilliseconds == 0 || lapLength == 0 || numLaps == 0 || raceDistance == 0) {
      return '0';
    }

    if(numLaps == previousLap) {
      int paceMinutes = currentPace.toInt();
      int paceSeconds = ((currentPace - paceMinutes) * 60).toInt();
      return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
    }
    // print('calculatePace2: $totalMilliseconds, $lapLength, $numLaps, $raceDistance');

    previousLap = numLaps;

    int metersRunSoFar = lapLength * numLaps;
    double totalSeconds = totalMilliseconds / 1000;
    double totalMinutes = totalSeconds / 60;
    double pace = totalMinutes / (metersRunSoFar / raceDistance);

    int paceMinutes = pace.toInt();
    int paceSeconds = ((pace - paceMinutes) * 60).toInt();

    currentPace = pace;

    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
  }

  String calculateNewPace(int totalMilliseconds, int lapLength, int numLaps, int raceDistance) {
    // print('calculateNewPace1: $totalMilliseconds, $lapLength, $numLaps, $raceDistance');
    if(totalMilliseconds == 0 || lapLength == 0 || numLaps == 0 || raceDistance == 0) {
      return '0';
    }

    if(numLaps == previousNewLap) {
      int paceMinutes = currentNewPace.toInt();
      int paceSeconds = ((currentNewPace - paceMinutes) * 60).toInt();
      return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
    }
    // print('calculateNewPace2: $totalMilliseconds, $lapLength, $numLaps, $raceDistance');

    previousNewLap = numLaps;

    //What was done already
    int millisecondsPriorToThisLap = 0;
    if(lapSplits.length > 1) {
      millisecondsPriorToThisLap = lapSplits[lapSplits.length - 2];
    }
    // print('millisecondsPriorToThisLap: $millisecondsPriorToThisLap');

    double totalSecondsPrior = millisecondsPriorToThisLap / 1000;
    double totalMinutesPrior = totalSecondsPrior / 60;
    // print('totalMinutesPrior: $totalMinutesPrior');

    //What is left
    int millisecondsForThisLap = 0;
    if(lapSplits.length == 1) {
      millisecondsForThisLap = lapSplits.last;
    }
    else {
      millisecondsForThisLap = lapSplits.last - millisecondsPriorToThisLap;
    }

    // print('millisecondsForThisLap: $millisecondsForThisLap');
    int numLapsLeftIncludingTheOneJustCompleted = raceDistance ~/ lapLength - numLaps + 1;
    // print('numLapsLeftIncludingTheOneJustCompleted: $numLapsLeftIncludingTheOneJustCompleted');

    double totalMinutesLeft = (millisecondsForThisLap * numLapsLeftIncludingTheOneJustCompleted) / 60000;
    // print('totalMinutesLeft: $totalMinutesLeft');
    double pace = totalMinutesPrior + totalMinutesLeft;
    // print('pace: $pace');

    int paceMinutes = pace.toInt();
    int paceSeconds = ((pace - paceMinutes) * 60).toInt();

    currentNewPace = pace;

    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}';
  }

  calculateLapTime(int i) {
    if(i == 0) {
      return formatMilliseconds(lapSplits[i]);
    }
    return formatMilliseconds(lapSplits[i] - lapSplits[i-1]);
  }

  void calculateGoalSplits() {
    goalSplits.clear();
    int goalMilliseconds = (goalTimeMinutes * 60 * 1000) + (goalTimeSeconds * 1000);
    double goalSplit = goalMilliseconds / (raceDistance / lapLength);
    for(int i = 1; i <= raceDistance / lapLength; i++) {
      goalSplits.add((goalSplit * i).toInt());
    }
  }
}
