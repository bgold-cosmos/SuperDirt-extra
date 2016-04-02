(
s.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
s.options.memSize = 8192 * 16; // increase this if you get "alloc failed" messages
s.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
s.options.numOutputBusChannels = 2; // set this to your hardware output channel size, if necessary
s.options.numInputBusChannels = 2; // set this to your hardware output channel size, if necessary
// boot the server and start SuperDirt
s.waitForBoot {
	~dirt = SuperDirt(2, s); // two output channels, increase if you want to pan across more channels
	~dirt.loadSoundFiles("/Users/bgold/tidal/samples/*");	// load samples (path can be passed) mono is assumed.
	s.sync; // wait for samples to be read

	~dirt.start(57120, [0, 0, 0, 0]);   // start listening on port 57120, create two busses each sending audio to channel 0
	(
		~d1 = ~dirt.orbits[0]; // one orbit
		~d2 = ~dirt.orbits[1];
		~d3 = ~dirt.orbits[2];
		~d4 = ~dirt.orbits[3];
	);
};
s.latency = 0.2; // increase this if you get "late" messages
)

// Add your own instruments here.
// If your SuperDirt instance is assigned to the variable ~dirt, you can livecode these synths.

(
var numChannels = ~dirt.numChannels;

SynthDef(\sqr, { |out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n, custom1, custom2 |
	var env, sound, dur, freq;
	dur = 1.0 * (end - begin)/speed;
	freq = n.midicps * speed;
	env = EnvGen.ar(Env.linen(0.002, dur, 0.002, amp*0.2, -3), timeScale:dur, doneAction:2);
	sound = Pulse.ar(freq*(1.0+ Sweep.kr(1,accelerate)), 0.5-custom1/2+Sweep.kr(1,custom2));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\kickdrum, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var env, sound, dur, click;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.5, amp, -3), timeScale:dur, doneAction:2);
	sound = SinOsc.ar(60.0);
	click = LPF.ar(WhiteNoise.ar(1), 1500) * Line.ar(1, 0, 0.02);
	OffsetOut.ar(out, DirtPan.ar(sound + click, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\kick808, {|out, speed=1, begin=0, end=1, pan, fb, amp=1, n |
	var env, sound, dur, freq;
	dur = 1.0 * (end - begin)/speed;
	freq = n.midicps;
	env = EnvGen.ar(Env.linen(0.01, 0, 1, amp, -3), timeScale:dur, doneAction:2);
	sound = LPF.ar(SinOscFB.ar(XLine.ar(100*freq, freq, 0.025/speed), fb), 9000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;


SynthDef(\hat, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var env, sound, dur;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.3, amp, -3), timeScale:dur, doneAction:2);
	sound = HPF.ar(LPF.ar(WhiteNoise.ar(1), 6000), 2000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\snaredrum, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var env, sound, dur, snap;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.6, amp, -3), timeScale:dur, doneAction:2);
	sound = LPF.ar(Pulse.ar(100), Line.ar(1030, 30, 0.2));
	snap = BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1500) * Line.ar(1, 0, 0.2);
	OffsetOut.ar(out, DirtPan.ar(sound + snap, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\clap, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var env, sound, dur;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.6, amp, -3), timeScale:dur, doneAction:2);
	sound = BPF.ar(LPF.ar(WhiteNoise.ar(1), 7500), 1500);
	sound = Mix.arFill(7, {arg i; sound * 0.5 * EnvGen.ar(Env.new([0,0,1,0],[0.01*i,0,0.04]))});
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\sinelong, { |out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n, feedback=0, offset |
	var env, sound, dur, freq;
	dur = (end - begin)/speed;
	freq = n.midicps * speed;
	env = EnvGen.ar(Env.linen(0.02, dur, 0.02, amp*0.2, -3), timeScale:dur, doneAction:2);
	sound = SinOscFB.ar(freq*(1.0+ Sweep.kr(1,accelerate)), feedback);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

~dirt.addModule('fm', { |dirtEvent|
	dirtEvent.sendSynth('dirt_fm' ++ ~dirt.numChannels,
		[fm: ~fm,	fmf: ~fmf,  out: ~out	]
	)
}, { ~fm.notNil or: { ~fmf.notNil } }); // play synth only if at least one of the two was given

SynthDef("dirt_fm" ++ numChannels, { |out, fm, fmf |
	var signal, mod;
	signal = In.ar(out, numChannels);
	mod = SinOsc.ar(fmf * (1.0 + fm * signal), mul:fm);
	ReplaceOut.ar(out, mod + (1.0-fm)*signal);
}).add;
//	}, [\ir, \ir]).add;


////////
// old stuff below here
////////
SynthDef(\siren, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, index, cps, offset |
	var env, sound, dur, freq;
	dur = (end-begin)/speed;
	freq = index.midicps;
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 0.2*amp, -2), timeScale:dur, doneAction:2);
	sound = VarSaw.ar(freq * (1.0 + EnvGen.kr(Env.linen(0.25,0.5,0.25,3,0), timeScale:dur, doneAction:2)), 0, Line.kr(0.05,1,dur));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\dropsy, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, index, cps, offset |
	var env, sound, dur, freq;
	dur = (end-begin)/speed;
	freq = index.midicps;
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1, 0.2*amp, -2), timeScale:dur, doneAction:2);
	sound = Pulse.ar(XLine.kr(freq, 0.5*freq, dur), Line.kr(0.0, 0.5, dur));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;


SynthDef(\static, {|out, speed=1, start=0, end=1, pan, accelerate, amp=1, index, offset |
	var env, sound, dur, freq;
	dur = 1.0 * (end-start)/speed;
	freq = index.midicps;
	env = EnvGen.ar(Env.sine(dur, amp*0.2), timeScale:dur, doneAction:2);
	sound = Dust.ar(freq*10);
	sound = sound > 0.5;
	sound = Pulse.ar(100,0.5) * sound;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\demo1, { |out, speed=1, start=0, end=1, pan, accelerate, amp=1, index, offset |
	var env, sound, dur, freq;
	dur = 0.3;
	freq = index.midicps * speed;
	env = EnvGen.ar(Env.perc(0.02/speed, 0.5, amp*0.3, -4), timeScale:dur, doneAction:2);
	sound = FBSineL.ar(freq*8, end);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\synth, {|out, speed=1, start=0, end=1, pan, accelerate, amp=1, index, offset|
	var env, sound, dur, freq;
	dur = 0.5 * (end-start)/speed;
	freq = index.midicps * speed;
	env = EnvGen.ar(Env.perc(0.01, 5/speed, amp*0.2, -4), timeScale:dur, doneAction:2);
	sound = FBSineC.ar(freq*16, im:Line.kr(amp*amp,amp*amp+accelerate), fb:0.1+start,
	a:1.0, c:0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\pmsin2, { |out, speed = 1, start=0, end=1, pan, accelerate, amp = 1, offset|
	var env, sound, dur, rate, phase, freq, modfreq;
	dur = (end - start) / speed * 0.5;
	freq = MouseX.kr(70, 80).round.midicps * speed;
	modfreq = MouseY.kr(200, 2000, 1);
	amp = AmpCompA.kr(freq) * amp;
	env = EnvGen.ar(Env.perc(0.002, dur, amp * 0.2, -1), timeScale:dur, doneAction:2);
	phase = Line.ar(start, end, dur);
	rate = speed + Sweep.kr(1, accelerate);
	sound = SinOsc.ar(freq, SinOsc.ar(modfreq * (1..5), 0, 1 - phase * 10 * env / (1..5), 0.5pi)).sum;
	OffsetOut.ar(out,
		DirtPan.ar(sound, ~dirt.numChannels, pan, env)
	)
}).add;

);
