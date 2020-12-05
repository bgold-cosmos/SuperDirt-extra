(
var numChannels = ~dirt.numChannels;
SynthDef(\se1, {|out, sustain, pan, accelerate, freq, voice=0|
	var sound, fenv, env, k, amps;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.49, 0.49, curve:[-2,2]), timeScale:sustain);
	sound = VarSaw.ar(freq) * Pulse.ar(freq, voice*LFSaw.ar(freq/100).range(0,1)).range(0,1);
	sound = LPF.ar(sound, Clip.ar(2820*(fenv**0.8), 20, 10e3));
	sound = tanh(2*sound**[1,2,4,8]);
	sound = Mix.ar(sound)*0.3;
	sound = SplayAz.ar(2, sound, 0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se2, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env, ratio, wid;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	wid = Line.ar(0.85,0.3, sustain);
	osc1 = Trig.ar(Impulse.ar(freq),wid/freq);
	ratio = Line.ar(3.1,5.7,sustain);
	osc2 = EnvGen.ar(Env([0,0,1,0,0], [0, 0.5,0.5,0], releaseNode:3, loopNode:0), osc1, timeScale:1/freq/ratio);
	sound = LeakDC.ar(osc2, 0.99);
	sound = LPF.ar(LPF.ar(sound,18e3), 15e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se3, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	osc1 = Trig.ar(Impulse.ar(freq) + Impulse.ar(freq, 0.6), 0.5/freq);
	osc2 = EnvGen.ar(Env([0,0,1,0,0], [0, 0.5,0.5,0], releaseNode:3, loopNode:0), osc1, timeScale:1/freq/2.4);
	sound = LeakDC.ar(osc2, 0.99);
	sound = LPF.ar(LPF.ar(sound,18e3), 15e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se4, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	osc1 = Trig.ar(Impulse.ar(freq*[1,1.01]), 0.5/freq);
	osc2 = EnvGen.ar(Env([0,0,1,-1,0,0], [0, 0.45,0.1,0.45,0], releaseNode:4, loopNode:0), osc1,
		timeScale:1/freq/Saw.ar([1,1.01]).range(1.5,3.5));
	sound = Mix.ar(osc2/2);
	sound = LeakDC.ar(sound, 0.99);
	sound = LPF.ar(LPF.ar(sound,18e3), 15e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se5, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	osc1 = Mix.ar(Trig.ar(Impulse.ar(freq,[0,0.01]), 0.5/freq));
	osc2 = EnvGen.ar(Env([0,0,1,-1,0,0], [0, 0.45,0.1,0.45,0], releaseNode:4, loopNode:0), osc1,
		timeScale:1/freq/(2.0*osc1+2.5));
	sound = Mix.ar(osc2*LeakDC.ar(osc1));
	sound = atan(sound*3*XLine.ar(1,0.3,sustain));
	sound = LeakDC.ar(sound, 0.99);
	sound = LPF.ar(LPF.ar(sound,8e3), 5e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se6, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	osc1 = Saw.ar(freq/2.01);
	osc2 = SinOsc.ar(freq*(5.0*osc1+1));
	sound = osc2 + DelayL.ar(osc2, 0.2, Line.ar(2.3,2.1,sustain)/freq);
	sound = atan(sound*3*XLine.ar(1,0.2, sustain)) * 0.7;
	sound = LeakDC.ar(sound, 0.99);
	sound = LPF.ar(LPF.ar(sound,8e3), 5e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se7, {|out, sustain, pan, accelerate, freq, voice=0|
	var osc1, osc2, sound, env, fs;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	fs = Wrap.ar(freq*[19/9, 7.21, 11.5, 60], 20, 8000);
	osc1 = Mix.ar(LFTri.ar(fs, [0,1,1,0.5], [0.5,0.9,0.8,0.7]));
	osc2 = LFTri.ar(osc1.linexp(-4,4,0.01,100) * freq);
	sound = osc2 + DelayL.ar(osc2, 0.2, Line.ar(2.3,2.1,sustain)/freq);
	sound = BLowShelf.ar(sound, 300, 1, -7);
	sound = atan(sound);
	sound = LeakDC.ar(sound, 0.99);
	sound = LPF.ar(sound, 8000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\se8, {|out, sustain, pan, accelerate, freq, voice=0|
	var sound, env;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	sound = Blip.ar(freq*[0.5,1,2,3,4], XLine.ar(128,4,sustain), mul:[0.2,0.5,0.5,0.1,0.1]);
	sound = CombL.ar(Mix.ar(sound), 1.2, SinOsc.kr(2/sustain, mul:[1,-1]/4000, add:1/66), -0.1);
	sound = LPF.ar(sound,8000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\moon1, {|out, sustain, pan, accelerate, freq, voice=0|
	var a, b, sound, env, fenv;
	freq = freq/8 * XLine.ar(1, exp(accelerate), sustain);
	//env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	env = EnvGen.ar(Env.perc(0.01, 2.0, 1.0, -4), timeScale:sustain, doneAction:2);
	a = Saw.ar(freq*XLine.ar(100,1,sustain/4));
	b = Pulse.ar(freq, width:0.5);
	b = [b, DelayL.ar(b, 1.0, delaytime:XLine.ar(1e-2,1e-4,sustain/4))];
	b = LPF.ar(b, 1e3);
	//sound = Mix.ar([a*env, b*(env**0.5)]);
	sound = wrap2(b,a);
	sound = CombL.ar(sound, 0.2, 1/freq/1, decaytime:-inf);
	sound = 0.8 * LPF.ar(sound, 8e3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\moon2, {|out, sustain, pan, accelerate, freq, voice=0|
	var a, b, sound, env, renv;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.perc(0.01, 0.5, 1.0, -4), timeScale:sustain);
	renv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	a = Mix.ar(VarSaw.ar(freq, iphase:[0,0.5], width:Line.ar(0.60,0.75, sustain)));
	b = Pulse.ar(freq*23/101, width:0.33);
	sound = (a * b) * env;
	sound = LPF.ar(sound, 8000);
	sound = JPverb.ar(sound, t60:sustain*4, damp:0.2, size:0.2, earlyDiff:0.7, modDepth:0.5, modFreq:0.5, high:0.49, mid:0.7);
	sound = atan(sound*10);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1));
}).add;

SynthDef(\moon3, {|out, sustain, pan, accelerate, freq, voice=0|
	var a, b, sound, env, renv;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.perc(0.01, 0.5, 1.0, -4), timeScale:sustain);
	renv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	a = LocalIn.ar(1);
	b = a;
	a = VarSaw.ar(freq, width:a*pi);
	b = Pulse.ar(freq/pi, width:0.5);
	LocalOut.ar(DelayL.ar(a*b, delaytime:a/200));
	sound = a + b;
	sound = Greyhole.ar(sound, sustain/4, size:5, diff:0.9, feedback:0.5, modDepth:1, modFreq:0.5);
	sound = Splay.ar(sound, spread:0.3)*renv;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1));
}).add;

SynthDef(\moon4, {|out, sustain, pan, accelerate, freq, voice=0|
	var a, b, sound, env1, env2, fenv;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env1 = EnvGen.ar(Env.perc(0.01, 0.5, 1.0, -4), timeScale:sustain);
	fenv = EnvGen.ar(Env.perc(0.05, 0.5, 1.0, -4), timeScale:sustain) * 100;
	env2 = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	a = RLPF.ar(WhiteNoise.ar, freq, 0.707);
	b = Resonz.ar(a, freq+fenv, 0.01, 10);
	b = Resonz.ar(b, freq, 0.1, 10);
	sound = HPF.ar((a*env1+b)*env2, freq);
	// sound = CombL.ar(sound, 0.2, 1/freq, 0.02);
	// sound = atan(sound*2.0);
	// sound = FreeVerb.ar(sound, 0.5, 0.2, 0);
	// sound = atan(sound*2);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1));
}).add;


)