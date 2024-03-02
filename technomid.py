#!/usr/bin/env python3
# technomid.py - Generate TECHNO.COM procedural melody as MIDI - (c) 2024 a dinosaur
# Home page: https://github.com/ScrelliCopter/TECHNO.COM
# SPDX-License-Identifier: Zlib  (https://opensource.org/license/Zlib)

import os
import struct
import math
from abc import ABC, abstractmethod
from pathlib import Path
from typing import BinaryIO, Iterable, Tuple
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
			raise ValueError("MIDI Program out of range")
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


class MIDIMetaTrackEnd(MIDIEvent):
	def serialise(self) -> bytes:
		return struct.pack(">BBB", 0xFF, 0x2F, 0x00)


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

	class Format(IntEnum):
		SINGLE   = 0
		MULTI    = 1
		SEQUENCE = 2

	def write_header(self, division: int, fmt: Format = Format.SINGLE, track_count: int = 1):
		self._file.write(b"MThd")
		self._file.write(struct.pack(">IHHH", 6, fmt, track_count, division))

	def write_track(self, events: Iterable[Tuple[int, MIDIEvent]]):
		self._file.write(b"MTrk")
		ofs = self._file.tell()
		self._file.write(b"\0\0\0\0")  # Blank length field to write later

		# Serialise and write out events
		payload_len = 0
		for event in events:
			data = event[1].serialise()
			length = self.encode_varint(event[0])
			self._file.writelines([length, data])
			payload_len += len(length) + len(data)

		# Fill in track length field
		self._file.seek(ofs)
		self._file.write(payload_len.to_bytes(4, byteorder="big"))
		self._file.seek(0, os.SEEK_END)

	# Variable integer, used by event deltas.
	# Up to 4 bytes can encode 7 bits each by setting the continuation bit (bit 8)
	def encode_varint(self, value: int) -> bytes:
		if value < 0x80:
			return value.to_bytes(1, byteorder="big")
		if value < 0x4000:
			return bytes([0x80 | (value >> 7), value & 0x7F])
		if value < 0x200000:
			return bytes([0x80 | (value >> 14), 0x80 | (value >> 7) & 0x7F, value & 0x7F])
		if value < 0x10000000:
			return bytes([0x80 | (value >> 21), 0x80 | (value >> 14) & 0x7F, 0x80 | (value >> 7) & 0x7F, value & 0x7F])
		else:
			raise ValueError("Variable integer out of range")


def generate(f: BinaryIO):
	def note_from_period(period: int, reference: int) -> (int, int):
		frequency = reference / max(1, period)        # Convert period to hz
		fnote = 69 + 12 * math.log2(frequency / 440)  # Convert pitch to MIDI note
		note = int(round(fnote))                      # Snap to nearest semitone
		bend = int(round((fnote - note) * 0x1000))    # Error is encoded as pitch bend
		return min(0x7F, note), min(0x1FFF, bend)

	def techno(length: int):
		timer = int(round((1000000 * 1260 / 88) / 12))  # Intel 8253 (PIC) clock in Mhz
		# Music tables from disassembly
		phrase = [2, *[1, 0, 0] * 3] * 3 + [2, 3] + [0, 3] * 3
		freq_tbl = [5424, 2712, 2416, 2280]
		mangler = 0x0404

		yield 0, MIDIMetaTempo(int(round((1000000 * 0x80000) / timer)))  # 16th note every two PIC ticks
		yield 0, MIDIProgramChange(0, 80)  # Set GM patch to #81 "Lead 1 (Square)"

		i = 0
		bend = 0
		while True:
			for sixteenth in phrase:
				note, new_bend = note_from_period(freq_tbl[sixteenth], timer)
				if new_bend != bend:
					yield 0, MIDIPitchWheel(0, new_bend)
					bend = new_bend
				yield 0, MIDINoteOn(0, note)
				yield 32, MIDINoteOff(0, note)
				i += 2
				if i >= length:
					yield 0, MIDIMetaTrackEnd()
					return
			# Scramble pitch table at the end of each measure
			mangler = (mangler + len(phrase) * 2) & 0xFFFF
			freq_tbl = [freq ^ mangler for freq in freq_tbl]

	mid = MIDIWriter(f)
	mid.write_header(128)
	mid.write_track(techno(80 * 25))


if __name__ == "__main__":
	with Path("techno.mid").open("wb") as f:
		generate(f)
