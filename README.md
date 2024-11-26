This repository includes the firmware and KiCAD schematic/PCB for my fan controller project.

The board uses USB-A for the 5 volt power supply, with 2 pairs of header pins for the separate fan power supply and fan wires respectively.

The firmware is written for the ATMEGA328P in AVR assembly, currently providing a sequence of three states: off, 100% duty cycle, and 50% duty cycle. It also manages button debouncing and reduces the relay contact noise, which is otherwise quite loud on the relay used in the schematic. Using a relay in this application, despite MOSFETs being more appropriate in most situations, allows using any choice of power supply for the fan.
