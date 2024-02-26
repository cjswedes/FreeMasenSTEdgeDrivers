# Subdriver stress test

Driver with many subdrivers to handle different messages.

Driver spins up 10 devices which will be setup to be toggled by a routine that is triggered by the Routine trigger device.
Capability event is emitted for each cmd to allow for pairing the timing of the device cmd/events

Subdrivers can be setup in the driver to handle different devices messages.

This is used in conjunction with logs analysis to measure the latency in a situation where a routine is triggering 
all devices to be toggled at once.

