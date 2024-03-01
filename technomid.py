#!/usr/bin/env python3
# technomid.py - Generate TECHNO.COM procedural melody as MIDI - (c) 2024 a dinosaur
# Home page: https://github.com/ScrelliCopter/TECHNO.COM
# SPDX-License-Identifier: Zlib  (https://opensource.org/license/Zlib)

import struct
import math
from abc import ABC, abstractmethod
from pathlib import Path
from typing import BinaryIO, List, Tuple
from enum import IntEnum


class MIDIEvent(ABC):
	@abstractmethod
	def serialise(self) -> bytes:
		pass


class MIDINoteOff(MIDIEvent):
	def __init__(self, channel: int, note: int, velocity: int = 64):
		if channel < 0 or channel > 0xF:
			raise ValueError("MIDI Channel out of range")
		if note < 0 or note > 0x7F:
			raise ValueError("MIDI Note out of range")
		if velocity < 0 or velocity > 0x7F:
			raise ValueError("MIDI Velocity out of range")
		self._channel = channel
		self._note = note
		self._velocity = velocity

	def serialise(self) -> bytes:
		return struct.pack(">BBB", 0x80 | self._channel, self._note, self._velocity)


class MIDINoteOn(MIDIEvent):
	def __init__(self, channel: int, note: int, velocity: int = 127):
		if channel < 0 or channel > 0xF:
			raise ValueError("MIDI Channel out of range")
		if note < 0 or note > 0x7F:
			raise ValueError("MIDI Note out of range")
		if velocity < 0 or velocity > 0x7F:
			raise ValueError("MIDI Velocity out of range")
		self._channel = channel
		self._note = note
		self._velocity = velocity

	def serialise(self) -> bytes:
		return struct.pack(">BBB", 0x90 | self._channel, self._note, self._velocity)


class MIDIProgramChange(MIDIEvent):
	def __init__(self, channel: int, patch: int):
		if channel < 0 or channel > 0xF:
			raise ValueError("MIDI Channel out of range")
		if patch < 0 or patch >= 0x80:
			raise ValueError("Program out of range")
		self._channel = channel
		self._patch = patch

	def serialise(self) -> bytes:
		return struct.pack(">BB", 0xC0 | self._channel, self._patch)


class MIDIPitchWheel(MIDIEvent):
	def __init__(self, channel: int, value: int = 0):
		if channel < 0 or channel > 0xF:
			raise ValueError("MIDI Channel out of range")
		if value < -8192 or value > 8191:
			raise ValueError("MIDI Pitch bend value out of range")
		self._channel = channel
		self._value = value + 0x2000

	def serialise(self) -> bytes:
		return struct.pack(">BBB", 0xE0 | self._channel, self._value & 0x7F, self._value >> 7)


class MIDIMetaTempo(MIDIEvent):
	def __init__(self, quarter_us: int):
		if quarter_us < 0 or quarter_us >= 0x1000000:
			raise ValueError("Quarter note microseconds out of range")
		self._quarter_us = quarter_us

	def serialise(self) -> bytes:
		return b"\xFF\x51\x03" + self._quarter_us.to_bytes(3, byteorder="big")


class MIDIWriter:
	def __init__(self, file: BinaryIO):
		self._file = file

	Format = IntEnum("Format", ["SINGLE", "MULTI", "SEQUENCE"])

	def write_header(self, division: int, fmt: Format = Format.SINGLE, track_count: int = 1):
		self._file.write(b"MThd")
		self._file.write(struct.pack(">IHHH", 6, fmt, track_count, division))

	def write_track(self, events: List[Tuple[int, MIDIEvent]]):
		payload = b""
		for event in events:
			payload += self.encode_varint(event[0])
			payload += event[1].serialise()
		self._file.write(b"MTrk")
		self._file.write(len(payload).to_bytes(4, byteorder="big"))
		self._file.write(payload)

	def encode_varint(self, value: int) -> bytes:
		if value < 0:
			raise ValueError("Variable integer must be positive")
		if value >= 0x10000000:
			raise ValueError("Variable integer is larger than 0FFFFFFF")
		if value < 0x80:
			return value.to_bytes()
		else:
			a = (value & 0xFE00000) >> 21
			b = (value & 0x01FC000) >> 14
			c = (value & 0x0003F80) >> 7
			d = (value & 0x000007F)
			if a != 0:
				return bytes([a | 0x80, b | 0x80, c | 0x80, d])
			elif b != 0:
				return bytes([b | 0x80, c | 0x80, d])
			elif c != 0:
				return bytes([c | 0x80, d])


def generate(outpath: Path):
	timer = round((1000000 * 14.31818) / 12)

	def note_from_period(period: int) -> (int, int):
		frequency = timer / max(1, period)
		fnote = 69 + 12 * math.log2(frequency / 440)
		note = int(round(fnote))
		bend = min(0x1FFF, int(round((fnote - note) * 0x1000)))
		return min(0x7F, note), bend

	def techno():
		phrase = [2, *[1, 0, 0] * 3] * 3 + [2, 3] + [0, 3] * 3
		freq_tbl = [5424, 2712, 2416, 2280]
		mangler = 0x0404

		i = 0
		bend = 0
		while True:
			for sixteenth in phrase:
				note, new_bend = note_from_period(freq_tbl[sixteenth])
				if new_bend != bend:
					yield 0, MIDIPitchWheel(0, new_bend)
					bend = new_bend
				yield 0, MIDINoteOn(0, note)
				yield 32, MIDINoteOff(0, note)
				i += 2
				if i >= 80 * 25:
					return
			mangler = (mangler + len(phrase) * 2) & 0xFFFF
			freq_tbl = [freq ^ mangler for freq in freq_tbl]

	with outpath.open("wb") as f:
		mid = MIDIWriter(f)
		mid.write_header(128)
		mid.write_track([
			(0, MIDIProgramChange(0, 80)),
			(0, MIDIMetaTempo(int(round((1000000 * 0x80000) / timer))))
		] + list(techno()))


if __name__ == "__main__":
	generate(Path("techno.mid"))
