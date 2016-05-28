{SinOsc.ar(440)}.play
{SinOsc.ar(440*1.618)}.play

Env.linen(1, 2, 3, 0.6, -3).test.plot;

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
s.latency = 0.3; // increase this if you get "late" messages
)

// Add your own instruments here.
// If your SuperDirt instance is assigned to the variable ~dirt, you can livecode these synths.

(
var numChannels = ~dirt.numChannels;

// a very basic starting point
SynthDef(\tutorial1, {|out|
	var sound = SinOsc.ar(440.0);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, 0.5));
}).add;

// now let's add some better duration control, and support for pan
// Tidal's synth parameters magically show up as arguments to the SynthDef!
// overall gain is already handled by SuperDirt, so we don't need it in the envelope
SynthDef(\tutorial2, {|out, begin=0, end=1, pan, speed=1 |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.01, dur, 0.01, 1,-3), timeScale:dur, doneAction:2);
	var sound = SinOsc.ar(440.0);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// it's also nice to control the pitch
// using midicps means the "n" parameter will be used as MIDI note number
// in Tidal we'll need to say something like `sound "tutorial3:69"` to hear a reasonably high pitch
SynthDef(\tutorial3, {|out, begin=0, end=1, pan, speed=1, accelerate, n |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.01, dur, 0.01, 1, -3), timeScale:dur, doneAction:2);
	var sound = SinOsc.ar(n.midicps * Line.kr(1,1+accelerate));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// we can also make the envelope more interesting
// note how speed affects the envelope
SynthDef(\tutorial4, {|out, begin=0, end=1, pan, speed=1, accelerate, n |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.perc(0.001/speed, 1/speed, 1, -4), timeScale:dur, doneAction:2);
	var sound = SinOsc.ar(n.midicps * Line.kr(1,1+accelerate));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// finally, as an example of how to add your own parameters, let's say we want precise control over frequency
// we'll make a new "f" parameter instead of "n" (don't use "freq", it's already used internally in SuperDirt)
// to do this, we first need to this in Tidal: let (f, f_p) = pF "f" (Just 440)
// then "f" is usable as an argument to the synthdef, and in Tidal you can try
// d1 $ s "tutorial5/2" # f "[550,555]" # speed "1"
SynthDef(\tutorial5, {|out, begin=0, end=1, pan, speed=1, accelerate, f |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.perc(0.001/speed, 1/speed, 1, -4), timeScale:dur, doneAction:2);
	var sound = SinOsc.ar(f * Line.kr(1,1+accelerate));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\basicmandolin, {|out, n, amp=1|
	var sound = Decay.ar(Impulse.ar(0), 0.1) * WhiteNoise.ar * amp;
	sound = CombL.ar(sound, 0.05, n.midicps.reciprocal);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, 0.5));
}).add;

// physical modeling of a vibrating string, using a delay line (CombL) excited by an intial pulse (Impulse)
// To make it a bit richer, I've combined two slightly detuned delay lines
// "accelerate" is used for a pitch glide, and "speed" changes the envelope timescale
SynthDef(\mandolin, {|out, speed=1, begin=0, end=1, pan, accelerate, n |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.002, dur, 0.002, 1,-3), timeScale:dur, doneAction:2);
	var sound = Decay.ar(Impulse.ar(0,0,0.1), 0.1*n/69) * WhiteNoise.ar;
	var pitch = n.midicps * Line.kr(1, 1+accelerate);
	sound = CombL.ar(sound, 0.05, pitch.reciprocal*0.998, dur) + CombL.ar(sound, 0.05, pitch.reciprocal*1.002, dur);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// *** include?
SynthDef(\bowed, {|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n, vel=0.5, force=1, pos=0.14 |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.002, dur, 0.002, amp*0.2,-3), timeScale:dur, doneAction:2);
	var sound = DWGSoundBoard.ar( DWGBowed.ar(n.midicps, velb:vel, force:force, pos:pos, c1:10) );
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// *** modify
SynthDef(\bgongo,{|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var dur = (end-begin)/speed;
	var basefreq = n.midicps;
	// lowest modes for free circular plate
	var freqlist =[ 1.000,  2.188,  5.091,  8.529,  8.950,  9.305, 13.746, 14.653, 19.462, 22.003, 24.888, 25.991,
		26.085, 30.509, 33.608, 35.081, 40.125, 42.023, 46.527, 49.481]**1.0;
	var tscale = 100.0 / basefreq / (freqlist**1);
	var ascale = 1.0 / (freqlist**0);
	var sound = Mix.arFill(15, {arg i; EnvGen.ar(Env.perc(0.01*tscale[i], 0.5*tscale[i], amp*0.5*ascale[i] ), timeScale:dur*5)
		* SinOsc.ar(basefreq * freqlist[i])});
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan))
}).add;

// an example of additive synthesis, building up a gong-like noise from a sum of sine-wave harmonics
// notice how the envelope timescale and amplitude can be scaled as a function of the harmonic frequency
// "tone" provides something like a tone knob, and "timbre" adjusts how the harmonics decay
// as in the other SynthDefs, "speed" affects the overall envelope timescale and "accelerate" for pitch glide
// for a demo, try this in Tidal
// d1 $ n (slow 2 $ fmap ((+50) . (*7)) $ run 8) # s "bgongc" # timbre "[1 0.2]/4" # tone "[0.5 0]/8"
SynthDef(\bgongc,{|out, speed=1, begin=0, end=1, pan, accelerate, n, tone=0, timbre=1 |
	var dur = (end-begin)/speed;
	var basefreq = n.midicps;
	// lowest modes for clamped circular plate
	var freqlist =[1.000,  2.081,  3.414,  3.893,  4.995,  5.954,  6.819,  8.280,  8.722,  8.882, 10.868, 11.180, 11.754,
		13.710, 13.715, 15.057, 15.484, 16.469, 16.817, 18.628]**1.0;
	var tscale = 100.0 / basefreq / (freqlist**timbre);
	var ascale =freqlist**tone;
	var sound = Mix.arFill(15, {arg i; EnvGen.ar(Env.perc(0.01*tscale[i], 0.5*tscale[i], 0.2*ascale[i] ), timeScale:dur*5)
		* SinOsc.ar(basefreq * freqlist[i] * Line.kr(1, 1+accelerate))});
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan))
}).add;

// hooking into a nice synth piano already in supercollider
// uses the "hard" parameter to affect how hard the keys are pressed
// "speed" controls envelope and decay time
SynthDef(\mdapiano,{|out, speed=1, begin=0, end=1, pan, hard=1, stretch=0.1, muffle=1, stereo=0.2, n |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.002, dur, 0.002, 1,-3), timeScale:dur, doneAction:2);
	// the +0.01 to freq is because of edge case rounding internal to the MdaPiano synth
	var sound = MdaPiano.ar(n.midicps+0.01, vel:hard*100, hard:0.8*hard, decay:0.4*dur,
		tune:0.5, random:0.05, stretch:stretch, muffle:0.8*muffle, stereo:stereo);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// waveguide mesh, hexagonal drum-like membrane
SynthDef(\membrane,{|out, speed=1, begin=0, end=1, pan, n, accelerate |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.02, dur, 0.02, 1,-3), timeScale:dur*speed, doneAction:2);
	var tension = 0.05*n.midicps/400 * Line.kr(1,accelerate+1);
	var loss = 1.0 - (0.01 * speed / n.midicps);
	var sound = MembraneHexagon.ar(Decay.ar(Impulse.ar(0,0,1), 0.01), tension, loss);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\bgong,{|out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n |
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.perc(0.001/speed, 1/speed, amp*0.3, -4), timeScale:dur, doneAction:2);
	var basefreq = n.midicps;
	var freqlist = [1.0, 3.893, 8.722, 2.081, 5.954, 3.414];
	var sound = Mix.arFill(4, {arg i; XLine.ar(1, 0.01, 10/freqlist[i]**4) * SinOsc.ar(basefreq * freqlist[i])});
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;


SynthDef(\nonlin, {|out, n, amp=1, pan, begin=0, end=1, accelerate, speed|
	var dur = (end-begin)/speed;
	var env = EnvGen.ar(Env.linen(0.01, dur, 0.01, amp*0.2, -3), timeScale:dur, doneAction:2);
	var source = Decay.ar(Impulse.ar(0), 0.1) * SinOsc.ar(n.midicps);
	var sound = WeaklyNonlinear2.ar(source, 0, 1, 1, n.midicps, 0, 0, -0.001, 3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;


SynthDef(\sqr, { |out, speed=1, begin=0, end=1, pan, accelerate, amp=1, n, custom1, custom2 |
	var env, sound, dur, freq;
	dur = 1.0 * (end - begin)/speed;
	freq = n.midicps * speed;
	env = EnvGen.ar(Env.linen(0.002, dur, 0.002, amp*0.2, -3), timeScale:dur, doneAction:2);
	sound = Pulse.ar(freq*(1.0+ Sweep.kr(1,accelerate)), 0.5-custom1/2+Sweep.kr(1,custom2));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// Kick Drum using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1
// "n" controls the kick frequency
// "speed" affects overall envelope timescale, "accelerate" sweeps the click filter freq,
// "tone" affects the click frequency, and "click" changes the click duration relative to the overall timescale
SynthDef(\kickdrum, {|out, speed=1, begin=0, end=1, pan, accelerate, n, tone=1, click=1 |
	var env, sound, dur, clickdur;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.5, 1, -3), timeScale:dur, doneAction:2);
	sound = SinOsc.ar((n+34.5).midicps);
	clickdur = 0.02*dur*click;
	sound = sound + (LPF.ar(WhiteNoise.ar(1), 1500*tone*Line.kr(1,1+accelerate,clickdur) ) * Line.ar(1, 0, clickdur));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// A vaguely 808-ish kick drum
// "n" controls the chirp frequency, "speed" the filter sweep speed, and "fb" the sinewave feedback
SynthDef(\kick808, {|out, speed=1, begin=0, end=1, pan, fb, n |
	var env, sound, dur, freq;
	dur = 1.0 * (end - begin)/speed;
	n = ((n>0)*n) + ((n<1)*3);
	freq = (n*10).midicps;
	env = EnvGen.ar(Env.linen(0.01, 0, 1, 1, -3), timeScale:dur, doneAction:2);
	sound = LPF.ar(SinOscFB.ar(XLine.ar(100*freq, freq, 0.025/speed), fb), 9000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// Hi-hat using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1
// using "n" in a weird way to provide some variation on the frequency
// "speed" affects the overall envelope rate, "accelerate" sweeps the filter
SynthDef(\hat, {|out, speed=1, begin=0, end=1, pan, accelerate, n |
	var env, sound, dur, accel, freq;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.3, 1, -3), timeScale:dur, doneAction:2);
	accel = Line.kr(1, 1+accelerate, 0.2*dur);
	freq = 2000*accel*(n/5 + 1).wrap(0.5,2);
	sound = HPF.ar(LPF.ar(WhiteNoise.ar(1), 3*freq), freq);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// Snare drum using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713909/drum-sounds-in-supercollider-part-2
// again using "n" for some variation on frequency, "snap" for scaling noise duration relative to tonal part
// "speed" for overall timescale, "accelerate" for tonal glide
SynthDef(\snaredrum, {|out, speed=1, begin=0, end=1, pan, accelerate, n, snap=1 |
	var env, sound, dur, accel;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.6, 1, -3), timeScale:dur, doneAction:2);
	accel = Line.kr(1, 1+accelerate, 0.2);
	sound = LPF.ar(Pulse.ar(100*accel*(n/5+1).wrap(0.5,2)), Line.ar(1030, 30, 0.2*dur));
	sound = sound + (BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1500) * Line.ar(1, 0, 0.2*snap));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// Hand clap using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713909/drum-sounds-in-supercollider-part-2
// "spread" controls the echo delay, "speed" will affect the decay time, "n" changes how spread is calculated
// "tone" will scale the bandpass frequency
SynthDef(\clap, {|out, speed=1, begin=0, end=1, pan, n, spread=1, tone=1 |
	var env, sound, dur;
	var spr = 0.005 * spread;
	dur = 1.0 * (end - begin)/speed;
	env = EnvGen.ar(Env.linen(0.01, 0, 0.6, 1, -3), timeScale:dur, doneAction:2);
	sound = BPF.ar(LPF.ar(WhiteNoise.ar(1), 7500*tone), 1500*tone);
	sound = Mix.arFill(4, {arg i; sound * 0.5 * EnvGen.ar(Env.new([0,0,1,0],[spr*(i**(n+1)),0,0.04/speed]))});
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

~dirt.addModule('envsaw', { |dirtEvent|
	dirtEvent.sendSynth('dirt_envsaw' ++ ~dirt.numChannels,
		[envsaw: ~envsaw, envsawf: ~envsawf, out: ~out])}, { ~envsaw.notNil;});
SynthDef("dirt_envsaw" ++ numChannels, { |out, envsaw, envsawf=10 |
	var signal, mod;
	signal = In.ar(out, numChannels);
	mod = ((Saw.ar(envsawf) * (-1)) + 1.0) * 0.5 * envsaw + 1.0 - envsaw;
	ReplaceOut.ar(out, signal * mod);
}).add;

~dirt.addModule('rectify', { |dirtEvent|
	dirtEvent.sendSynth('dirt_rectify' ++ ~dirt.numChannels,
		[rect: ~rect, rectoff: ~rectoff, out: ~out])}, { ~rect.notNil});
SynthDef("dirt_rectify" ++ numChannels, { |out, rect, rectoff=0 |
	var signal;
	signal = In.ar(out, numChannels);
	ReplaceOut.ar(out, signal.fold(rectoff-rect, rect+rectoff) / rect);
}).add;

~dirt.addModule('wrap', { |dirtEvent|
	dirtEvent.sendSynth('dirt_wrap' ++ ~dirt.numChannels,
		[wrap: ~wrap, wrapoff: ~wrapoff, out: ~out])}, { ~wrap.notNil});
SynthDef("dirt_wrap" ++ numChannels, { |out, wrap, wrapoff=0 |
	var signal;
	signal = In.ar(out, numChannels);
	ReplaceOut.ar(out, signal.wrap(wrapoff-wrap, wrap+wrapoff) / wrap);
}).add;


// NOW IN CORE
// ~dirt.addModule('envelope', { |dirtEvent|
// 	dirtEvent.sendSynth('dirt_envelope' ++ ~dirt.numChannels,
// [attack: ~attack, hold: ~hold, release:~release, out: ~out])}, { ~attack.notNil and: {~release.notNil}});
// SynthDef("dirt_envelope" ++ numChannels, { |out, attack=0, hold=0, release=100 |
// 	var signal;
// 	signal = In.ar(out, numChannels);
// 	ReplaceOut.ar(out, signal * EnvGen.ar(Env.linen(attack, hold, release, 1, -3)) );
// }).add;


//	}, [\ir, \ir]).add;

// a controllable synth siren, defaults to 1 second, draw it out with "speed"
SynthDef(\siren, {|out, speed=1, begin=0, end=1, pan, n |
	var env, sound, dur, freq;
	dur = (end-begin)/speed;
	freq = n.midicps;
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, -2), timeScale:dur, doneAction:2);
	sound = VarSaw.ar(freq * (1.0 + EnvGen.kr(Env.linen(0.25,0.5,0.25,3,0), timeScale:dur, doneAction:2)), 0, Line.kr(0.05,1,dur));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

////////
// old stuff below here
////////

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
