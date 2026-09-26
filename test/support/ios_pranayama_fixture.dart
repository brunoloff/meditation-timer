// Short, whole-cycle segments keep native smoke tests quick and deterministic.
const iosPranayamaEntries = [
  {
    'type': 'preset',
    'preset': {
      'id': 'ios-breathing',
      'name': 'iOS breathing test',
      'segments': [
        {
          'id': 'first',
          'durationSeconds': 8,
          'inBreathSeconds': 2,
          'firstHoldSeconds': 0,
          'outBreathSeconds': 2,
          'secondHoldSeconds': 0,
        },
        {
          'id': 'second',
          'durationSeconds': 12,
          'inBreathSeconds': 3,
          'firstHoldSeconds': 0,
          'outBreathSeconds': 3,
          'secondHoldSeconds': 0,
        },
      ],
    },
  },
];
