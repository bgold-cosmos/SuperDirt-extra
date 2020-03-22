// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.


// MIDI out startup
(
var server = server ? Server.default;

server.options.numBuffers = 1024 * 16; // increase this if you need to load more samples
server.options.memSize = 8192 * 64; // increase this if you get "alloc failed" messages
server.options.maxNodes = 1024 * 32; // increase this if you are getting drop outs and the message "too many nodes"
server.options.numInputBusChannels= 0; // to avoid issues of sample rate mismatch
server.options.numWireBufs = 1280;
// boot the server and start SuperDirt
server.waitForBoot {
	~dirt = SuperDirt.start(path:"/Users/bgold/tidal/samples/*", numOrbits:4);
	// MIDIClient.init;  // uncomment these lines for MIDI output
	// ~midiOut = MIDIOut.newByName("IAC Driver", "Bus 1");
}
)

// sidechain orbit 2 using orbit 3
(
~modBus.free;
~carBus.free;
~dirt.orbits[2].outBus = 0;
~dirt.orbits[3].outBus = 0;
// --- //
~modBus = Bus.audio(s, numChannels:2); // assuming stereo, expand if needed
~carBus = Bus.audio(s, numChannels:2);
~dirt.orbits[3].outBus = ~modBus; // play into that bus.
~dirt.orbits[2].outBus = ~carBus;
Ndef(\x, {
    var modBus = In.ar(~modBus, 2);
    var carBus = In.ar(~carBus, 2);
    var out = modBus+carBus;
    //carBus = FreeVerb.ar(carBus, 0.9, 0.8, 0.8);
	out = Compander.ar(carBus, modBus, -30.dbamp, 1, 0.01, 0.01, 0.07)+modBus;
    //out = Compander.ar(out, out, -15.dbamp, 1, 0.2);
    Out.ar(0, out);
})
)


//~dirt.soundLibrary.addMIDI(\midi, ~midiOut);
~dirt.orderModules([\lpf, \bpf]);
~dirt.orderModules([\wrap, \shape]); // swapped from default
~dirt.orderModules([\shape, \wrap]); // back to default

(
var diversions = ();  // make a dictionary of functions
~diversions = diversions; // make it available out of scope
// use the "diversion" key as a hook for playing the synth
// return nil (unless you want the default action to also happen)
~dirt.orbits[0].defaultParentEvent[\diversion] = { diversions[~s].value };
)

(
~diversions[\order] = {
	~dirt.orderModules([\sound, ~before.asSymbol, ~after.asSymbol]);
};
)


( // this bit should show all "instrument" synthDefs
var keys = SynthDescLib.global.synthDescs.keys;
keys = keys.select( {|k,i|
	var notSys = "system_".matchRegexp(k.asString).not;
	var notDirt = "dirt_".matchRegexp(k.asString).not;
	notSys && notDirt;
});
keys.asList.sort.do{|x| postln(x)};
nil;
)

( // this bit should show all "effect" synthDefs, and maybe a few others, assuming they start with "dirt_"
// this is a bit less useful since it doesn't really hint at Tidal keywords
var keys = SynthDescLib.global.synthDescs.keys;
keys = keys.select( {|k,i| "dirt_".matchRegexp(k.asString);});
keys.asList.sort.do{|x| postln(x)};
nil;
)

Server.local.options
~dirt.modules.collect({|x| x.name})

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


)

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
( /////// CONSIDER THE FOLLOWING /////////////
var server = server ? Server.default;
var numChannels = ~dirt.numChannels;
var synthbuf = Buffer.alloc(server, server.sampleRate * 4, 1);
var recbuf = Array.fill(9, {|x| Buffer.alloc(server, server.sampleRate*4,1)});
var notebus = Bus.control(s,1);
var dronebus = Bus.control(s,5);
var ringfunc = {|a,b| a*a+b;};
var samplebuf = Buffer.read(server, "/Users/bgold/tidal/samples/rave/AREUREADY.wav");
var fxbus = Bus.audio(s,2);

var sinbuf = Buffer.alloc(server, server.sampleRate, 1);

SynthDef(\noop, {}).add;

// input with big gain
SynthDef(\in, { |out, sustain = 1, speed = 1, begin = 0, end = 1, pan, accelerate, offset|
	var sound, rate, phase;
	var env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	phase = Line.ar(begin, end, sustain);
	rate = (begin + 1) * (speed + Sweep.ar(1, accelerate));
	sound = (SoundIn.ar(0) - SoundIn.ar(1));
	sound = tanh(10.0*sound);
	OffsetOut.ar(out,
		DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\out, {|out, sustain=1, pan, begin, end,loop=1|
	var sound, phase;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	phase = LFSaw.ar(loop/sustain, 1).range(begin,end);
	sound = BufRd.ar(1, synthbuf, phase);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superw, {|out, sustain, pan, accelerate, freq, voice=0|
	var sound, env, k, amps;
	k = Array.series(20, 1)*2-1;
	amps = 3.0e-1 / (k**0.8);
	env = EnvGen.ar(Env.perc(0.5, 0.5, curve:[-2,2]), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = Saw.ar(freq * k + [0.2,-0.2], amps) * Pulse.ar(freq, Saw.ar(freq).range(0.4,0.6)).range(0,1);
	sound = Mix.ar(sound*(env**0.5));
	sound = atan(sound*10);
	sound = LPF.ar(sound, Clip.ar((0.5+voice)*820*(env**1.8), 20, 20e3));
	sound = SplayAz.ar(2, sound, 0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1.0));
}).add;


SynthDef(\superwannabe, {|out, sustain, pan, accelerate, freq, voice=0|
	var sound, env, fenv, k, km, amps, phases, ramp;
	k = Array.series(40, 1);
	km = k ** (1.01);
	amps = 3.0e-2 / (k**1.2);
	phases = (k * pi).mod(2pi);
	ramp = Line.ar(0,0.5,sustain);
	env = EnvGen.ar(Env.triangle(1), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = SinOsc.ar(freq * k, phases*ramp*SinOsc.ar(freq*km)*SinOsc.ar(6).range(0.99,1.01), amps);
	sound = Mix.ar(sound*env);
	sound = atan(sound*30);
	sound = LPF.ar(sound, Clip.ar((0.5+voice)*5520*(env**1.8), 20, 20e3));
	sound = SplayAz.ar(2, sound, 0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1.0));
}).add;

SynthDef(\superpad, {|out, sustain, pan, accelerate, freq, voice|
	var sound, env, chop, fb, fr, cc;
	env = EnvGen.ar(Env.linen(0.4, 0.2, 0.4), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	fr = Line.ar(2.05, 1.95, sustain, mul:[1.01, 0.99]);
	sound = SinOscFB.ar(freq/fr, 4).range(freq-10, freq+10);
	fb = Line.ar(0.5, 0.8, sustain);
	sound = Mix.ar(SinOscFB.ar(sound*[0.48, 0.745, 1, 3.2], fb, mul:[0.3, 0.2, 1, 0.2]));
	chop = Saw.ar(freq + SinOsc.ar(1/sustain).range(-2,2));
	cc = EnvGen.ar(Env.perc(0.5, 0.5, curve:1), timeScale:sustain, levelScale:-0.2, levelBias:0.2);
	sound = sound * (chop < cc);
	sound = BLowPass4.ar(BLowPass4.ar(sound, 8000, 1.5), 7500, 2.5);
	sound = LeakDC.ar(sound);
	sound = Splay.ar(sound, 0.5, levelComp:true); // TODO: multichannel
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superclassic, {|out, sustain, pan, accelerate, freq, voice|
	var sound, fenv, env, env2;
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	env2 = EnvGen.ar(Env.linen(clip(0.03*sustain, 0.03, 0.1), 0.9*sustain, 0.07*sustain));
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = Pulse.ar(freq + [1,-1]);
	sound = Integrator.ar(env2 * PulseDivider.ar(sound, 2), 0.995);
	// sound = sound + Integrator.ar(PulseDivider.ar(sound, 2), 0.995);
	sound = sound + sound.product;
	sound = LeakDC.ar(sound);
	sound = 1.5*atan(sound*0.3);
	// sound = 0.3*atan(sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\superharm, {|out, sustain, pan, accelerate, freq, voice, lfo=0.5, decay, pitch1=1, pitch2=1|
	var sound, menv, env, es, os, as, fenv;
	menv = EnvGen.ar(Env.perc(0.05, 1.5), timeScale:sustain, doneAction:2);
	env = Array.fill(7, {EnvGen.ar(Env.perc(ExpRand(0.01, 0.05), ExpRand(0.5, 1.5)), timeScale:sustain)});
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	es = freq * [2,4,6,8,12,16,22] * pitch1;
	os = freq * [3,5,7,11,17,19,29] * pitch2;
	as = [10, 7, 5, 4, 3, 2, 1, 1]/100;
	es = SinOsc.ar(es, mul:as);
	es = BLowPass4.ar(es, 5*freq, 0.3) * env;
	os = SinOsc.ar(os, mul:as);
	os = BLowPass4.ar(os, 5*freq, 0.3) * env;
	sound = SinOsc.ar(freq, mul:menv*0.5) + Mix.ar( SelectX.ar(voice*SinOsc.kr(5, mul:0.5, add:0.5), [es, os]) );
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, 1))
}).add;

SynthDef(\supermod, {|out, sustain, pan, accelerate, freq, voice, lfo=0.5, decay, detune, pitch2=1.5|
	var sound, osc1, osc2, env, f2, fm;
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	f2 = freq * pitch2 + detune + 0.01;
	fm = SinOsc.ar(0.8).linexp(-1,1, 1/(1+lfo), 1+lfo);
	osc2 = SelectX.ar(voice, [Impulse.ar(f2), SinOsc.ar(f2), VarSaw.ar(f2), Pulse.ar(f2), Saw.ar(f2)]).linexp(-1,1,1/fm,fm);
	osc1 = SelectX.ar(voice, [SinOsc.ar(freq*osc2), VarSaw.ar(freq*osc2), Pulse.ar(freq*osc2), Saw.ar(freq*osc2), Impulse.ar(freq*osc2)]);
	sound = osc1;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\synthdev, {|out, sustain, pan, freq|
	var env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	var fenv = EnvGen.ar(Env.perc(0.05, 1.5), timeScale:sustain);
	var sound = Mix.ar(Pulse.ar(freq + [-1,0,1], [0.5, 0.2+SinOsc.kr(4,0,0.2,0.2), 0.8+SinOsc.kr(4,0.5,0.2,0.2)]));
	sound = RLPF.ar(sound, fenv * [800, 1100, 1300] + 15, [0.5,0.3, 0.4]);
	sound = Splay.ar(sound, 0.5);
	sound = sound + DelayL.ar(sound, 0.1, SinOsc.ar(0.1, [0, 0.25, 0.5], 0.005, 0.01));
	OffsetOut.ar(out, DirtPan.ar(0.35 * sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\synthdev2, {|out, sustain, pan, freq|
	var env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	var sound = Pulse.ar(freq + LPF.ar(Pulse.ar(220, 0.5, freq/8, 0), freq), LPF.ar(Pulse.ar(110, 0.5, 0.2, 0.5), freq));
	sound = LPF.ar(LPF.ar(sound, 8000), 8100);
	sound = sound + DelayL.ar(sound, 0.1, LPF.ar(Pulse.ar(0.1, [0.4, 0.6], 0.001, 0.01), 60));
	OffsetOut.ar(out, DirtPan.ar(0.35 * sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\synthdev3, {|out, sustain, pan, freq|
	var env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	var sound, o1, o2, o2p;
	o2p = LocalIn.ar(1);
	o1 = LPF.ar(Pulse.ar(0.99*freq+o2p, 0.4+(o2p*0.1)), 4000);
	o2 = LPF.ar(Pulse.ar(1.01*freq+o1, 0.6+(o1*0.1)), 4000);
	LocalOut.ar(o2);
	sound = o1+o2;
	sound = sound + DelayL.ar(sound, 0.1, 1/[1100,1350]);
	sound = Latch.ar(sound, Pulse.ar([8000,8001]));
	sound = LPF.ar(sound, 8000);
	OffsetOut.ar(out, DirtPan.ar(0.35 * sound, ~dirt.numChannels, pan, env))
}).add;


{
	var wave = Mix.ar(SinOsc.ar([1,2,3,0.5]));
	wave = LeakDC.ar(wave * wave - wave, 0.9995);
	BufWr.ar(wave, sinbuf, Phasor.ar(0, 1, 0, BufFrames.kr(sinbuf)),0);
	0;
}.play;

SynthDef(\synthdev4, {|out, sustain, pan, freq|
	var env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	var penv = EnvGen.ar(Env.perc(0.02, 2, 44100), timeScale:sustain);
	var sound, scan;
	scan = SinOsc.ar(freq) + (0.2*VarSaw.ar(freq*0.75, [0, 0.5], Line.ar(0.3,0,sustain)));
	sound = BufRd.ar(1, sinbuf, scan * penv, interpolation:1);
	sound = 0.5*LPF.ar(LPF.ar(sound, 8000), 8100);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;


SynthDef(\supertrip, {|out, pan, freq, sustain, accelerate|
	var env, fb, sound, aa, bb;
	freq = freq * XLine.ar(1, exp(accelerate), sustain) * (0.9 * PitchShift.ar(LocalIn.ar(1), 0.2, 8.0, 0.5) + 1.0);
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1), timeScale:sustain, doneAction:2);
	aa = LFPulse.ar(freq*2.001, width:0.5);
	bb = LFPulse.ar(freq*3.002, width:0.3);
	sound = SetResetFF.ar(aa, bb);
	sound = 2.0 * LeakDC.ar(sound);
	LocalOut.ar(sound);
	OffsetOut.ar(out, DirtPan.ar(Splay.ar([sound, sound+aa-bb], 0.4), ~dirt.numChannels, pan, env));
}).add;

SynthDef(\supernonlin, {|out, pan, freq, sustain, voice, accelerate|
	var env, fb, sound;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1), timeScale:sustain, doneAction:2);
	sound = SinOscFB.ar(freq, 0.5);
	sound = WeaklyNonlinear.ar(sound, reset:0, freq:freq, alpha:0.005, xexponent:1, beta:-1);
	sound = LagUD.ar(sound, 1/12000, 1/140);
	sound = DelayL.ar(sound, 0.1, 0.030);
	sound = LagUD.ar(sound, 1/200, 1/8000);
	sound = LeakDC.ar(sound);
	sound = atan(sound*3);
	// sound = SinOscFB.ar(freq, sound.range(0,1));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superdeep, {|out, pan, freq, sustain, voice, accelerate|
	var env, fb, sound;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1), timeScale:sustain, doneAction:2);
	sound = VarSaw.ar(freq, 0, LocalIn.ar() * (voice/2) + 0.5);
	sound = LagUD.ar(sound.clip2(0.9), 1/440, 1/8000);
	LocalOut.ar(sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	// OffsetOut.ar(out, DirtPan.ar([sound, DelayC.ar(sound, 0.2, 0.001)], ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superdeep2, {|out, pan, freq, sustain, accelerate|
	var env, sound;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	sound = VarSaw.ar(freq, 0, 0, mul:0.5) - VarSaw.ar(freq+(0.8*sustain), 0.1, 0, mul:0.5);
	sound = LagUD.ar(sound, 1/2040, 1/8000);
	sound = RLPFD.ar(sound, (sqrt(freq/1440.0) * 1440).clip(20,15000), 0.2, 0.2, mul:3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superbass, {|out, pan, freq, sustain, detune, accelerate|
	var sound, env, fenv, fd;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.2,2, 2), timeScale:sustain);
	fd = 0.01 + detune;
	sound = Mix.ar(SawDPW.ar(freq*[1-fd,1+fd], [-0.5, 0.5]));
	sound = 3.0*RLPFD.ar(sound, (4256*((freq/4256)**0.5)*fenv).clip(20,20000), 0.2);
	sound = sound + (1.0 * clip(0.5*LPF.ar(sound, freq), -0.25,0.25) );
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superbell, {|out, pan, freq, sustain, accelerate|
	var sound, aenv, freqmults, amps, ringtimes;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	aenv = EnvGen.ar(Env.perc(0.01, 2, 1, -3), timeScale:sustain, doneAction:2);
	freqmults = [1.0        , 1.26624044,
       1.53254558, 1.79888688, 2.06525043, 2.33162862, 2.59801696,
       2.86441263, 3.13081377, 3.39721908, 3.66362766];
	amps = Array.fill(11, {|i| exp(-1.0*i/11)});
	ringtimes = Array.fill(11, {|i| 0.3 + (i*0.3) + (i*i/4.0)});
	sound = DynKlank.ar(`[ freqmults, amps, ringtimes], Impulse.ar(0.1), freqscale:freq);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

SynthDef(\superwide, {|out, pan, freq, sustain, accelerate|
	var sound, mod, aenv, fenv, samp, trig;
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	sound = LagUD.ar(VarSaw.ar(freq, [0,0.1], 0.01), 1.0/900, 1.0/200)
	- LagUD.ar(VarSaw.ar(freq*1.01, [0.5,0.67], 0.03), 1.0/900, 1.0/200);
	sound = LeakDC.ar(sound);
	sound = RLPF.ar(RLPF.ar(sound, freq*7, 1/5.5), freq*3, 1/1.2);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

SynthDef(\superblip2, {|out, pan, freq, sustain|
	var sound, mod, aenv, fenv, samp, trig;
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	sound = Blip.ar(freq+Blip.ar(freq*1.98, 30, freq/5),  20 * Blip.ar(freq/2.01, 2).range(0,1));
	sound = LPF.ar(sound, 4*freq + Blip.ar(freq/32, 5).range(0,freq));
	sound = tanh(5.0*sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

SynthDef(\superrand, {|out, pan, freq, sustain|
	var sound, mod, aenv, fenv, samp, trig;
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	sound = Mix.ar(Impulse.ar(freq, Array.fill(50, {|i| Rand(0,1)}), Array.fill(50, {|i| Rand(-1,1)}) ));
	sound = LPF.ar(sound, 13000);
	sound = 0.5*atan(5*sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

SynthDef(\supercombo, {|out, pan, freq, sustain, voice|
	var sound, aenv, shift, switch;
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	shift = 0.2 / sustain;
	switch = voice.linexp(0, 1, 0.5, 2);
	sound = SelectX.ar(SinOsc.ar(freq*switch).range(0,1), [SinOsc.ar(freq + shift), Saw.ar(freq - shift)]);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv))
}).add;

SynthDef(\supersync2, {|out, pan, freq, sustain|
	var sound, mod, aenv, fenv, samp, trig;
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	// samp = Mix.ar(SinOsc.ar([20,30,440,800,1100], [0.1, 0.2,0,0.5,0], [0.3, 0.3, 1, 0.5, 0.3]));
	samp = Mix.ar(Saw.ar((freq*[3.5, 4.5]+[200, 605])));
	BufWr.ar(samp, sinbuf, Phasor.ar(0, BufRateScale.kr(sinbuf), 0, BufFrames.kr(sinbuf)));
	trig = Mix.ar(Impulse.ar(freq*[0.99,1.01]));
	sound = BufRd.ar(1, sinbuf, Phasor.ar(trig, BufRateScale.kr(sinbuf), 0, BufFrames.kr(sinbuf)));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

// tried a local buffer but it clicks and pops sometimes (running out of samples to read?)
SynthDef(\supersync3, {|out, pan, freq, sustain|
	var sound, mod, aenv, fenv, samp, trig;
	aenv = EnvGen.ar(Env.linen(0.05, 0.85, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.2, 0.7, 1, -1), timeScale:sustain);
	samp = 0.5*Mix.ar(Pulse.ar([freq*1.2, freq*3.14, 800, 1100, 2100], XLine.ar(0.5, 0.2, 0.01)));
	BufWr.ar(samp, sinbuf, Phasor.ar(0, 0.25, 0, BufFrames.kr(sinbuf)));
	trig = Mix.ar(Impulse.ar(freq*[1.001,0.999]));
	sound = BufRd.ar(1, sinbuf, Phasor.ar(trig, 1, 0, BufFrames.kr(sinbuf), Line.ar(0,40,sustain)));
	// sound = BufRd.ar(1, sinbuf, Phasor.ar(trig, 1, 0, BufFrames.kr(sinbuf)));
	sound = LeakDC.ar(sound);
	sound = LPF.ar(sound, 8000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

SynthDef(\superscratch,  {|out, pan, freq, sustain, accelerate, detune=0|
	var sound;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = Dust2.ar(freq);
	sound = Mix.ar(Resonz.ar(sound, freq*[1.1, 2.5+detune, 5, 23], 0.1, mul:10));
	sound = CombL.ar(sound, 0.2, XLine.ar(0.0001, 0.00011, sustain), 0.01);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superx1,  {|out, pan, freq, sustain, accelerate, detune=0|
	var sound;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = Saw.ar(freq * (detune/100+1.01)) - Saw.ar(freq * (-1*detune/100+0.99));
	sound = RLPF.ar(sound, (freq*64).clip(5,20000), 0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superx2,  {|out, pan, freq, sustain, accelerate,detune=0, voice=0|
	var sound, vcut;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	vcut = voice.linexp(0,1,1,0.1);
	sound = Saw.ar(freq) + Saw.ar(1.5*freq*(detune/100+1), 0.2) + Pulse.ar(freq/2.0*(detune/100+1), 0.5, 0.5);
	sound = tanh(5.0*sound/vcut);
	sound = RLPF.ar(sound, (freq*16*vcut).clip(20,20000), freq.linexp(20,4000,0.3,0.5));
	sound = 0.5*RLPF.ar(sound, (freq*24*vcut).clip(20,20000), freq.linexp(40,8000,0.3,1.0));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superx3,  {|out, pan, freq, sustain, accelerate, voice=0, pitch1, pitch2=4, lfo=0|
	var sound;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	sound = Saw.ar(freq * 1.01) - Saw.ar(freq * 0.99) + Pulse.ar(freq/1.98, 0.1, 0.2) - Pulse.ar(freq/2.02, 0.11, 0.2);
	sound = RLPF.ar(sound, freq*4, 0.3);
	sound = Notch.ar(sound, freq*1.5 * (SinOsc.ar(freq*0.67).linexp(-1,1,0.5,1.5)), 0.2);
	sound = tanh(2*sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superx4,  {|out, pan, freq, sustain, accelerate, voice=0, pitch1, pitch2=4, lfo=0|
	var sound, local, localcv, lfowave;
	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	freq = freq * XLine.ar(1, exp(accelerate), sustain);
	local = LocalIn.ar(1);
	localcv = LocalIn.kr(1);
	sound = Pulse.ar(freq*local/15+freq, local/8.0+0.125);
	LocalOut.ar(sound);
	lfowave = SinOsc.kr(localcv*1.5 + (freq/4.0));
	LocalOut.kr(lfowave);
	sound = RLPF.ar(sound, freq*lfowave.linexp(-1,1,12,13), 0.1);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// burninates the cpu
// SynthDef(\superspec,  {|out, pan, freq, sustain, accelerate, voice=0, pitch1, pitch2=4, lfo=0|
// 	var sound, sound2, lfowave;
// 	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
// 	freq = freq * XLine.ar(1, exp(accelerate), sustain);
// 	lfowave = 1.0 - SinOsc.kr(pitch2).range(0, lfo);
// 	sound = Splay.arFill(21, {|x| DynKlang.ar(
// 		`[Array.series(12,1+((x-10)/(315*voice+35)))+Array.rand2(12,0.01),
// 			exp(-0.5*((x-10)/3.0)**2) ! 12,
// 	Array.rand2(12,pi)], freq)/ 21}, spread:0.3, levelComp:false);
// 	sound = BHiShelf.ar(sound, 800*lfowave, 1, -20);
// 	sound2 = DynKlang.ar(`[Array.series(12,1), sqrt(1.0/Array.series(12,1)), Array.rand2(12,pi)], freq*(1.0+pitch1))/4.0;
// 	sound2 = RLPF.ar(sound2, freq*(2+pitch1)*lfowave, 0.5);
// 	sound = sound + sound2;
// 	OffsetOut.ar(out, DirtPan.ar(0.2*sound, ~dirt.numChannels, pan, env));
// }).add;

// SynthDef(\superspecfft,  {|out, pan, freq, sustain, speed, detune, accelerate, voice, pitch1|
// 	var snd, buf, chain, magsphases;
// 	var lb = LocalBuf(1024);
// 	var env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
// 	snd = WhiteNoise.ar(1);
// 	chain = FFT(lb, snd);
// 	magsphases = UnpackFFT(chain, 1024);
// 	magsphases = magsphases.collect({|x,i|
// 		x * cos( i*20/freq * pi)**2
// 		// x * exp(-0.5 * ((i-(freq/20))/10.0)**2)
// 	});
// 	chain = PackFFT(chain, 1024, magsphases);
// 	// chain = chain.pvcollect(1024, {|mag, phase, bin|
// 	// 	var fftf = (bin) * 44100.0/4096;
// 	// 	var g = exp(-0.5 * (((fftf-440)/5.0)**2));
// 	// 	[mag*g, phase];
// 	// });
// 	snd = IFFT(chain);
// 	OffsetOut.ar(out, DirtPan.ar(snd, ~dirt.numChannels, pan, env));
// }).add;

// from efairbanks
SynthDef(\workinprogress, {
    |out, sustain = 1, freq = 440, begin=0, end=1, pan, accelerate|
    var line = Line.ar(begin, end, sustain, doneAction:2);
	var env = Env([0, 1, 0], [0.05, 0.5], curve:[1,-1]);
    var envGen = IEnvGen.ar(env, line*env.times.sum);
    var sound = Mix.ar(Array.fill(20,{|i|Pulse.ar(ExpRand.new(20.0,2000.0),0.1)}));
	var fs = Array.fill(10, {|i| i+1});
	sound = Mix.ar(BPF.ar(sound,DC.ar(fs**1.262)*freq, (4/1000))*DC.ar(1.0/(fs**1.5)));
    OffsetOut.ar(out, DirtPan.ar(10.0*sound, ~dirt.numChannels, pan, envGen));
}).add;

SynthDef(\superds, {|out, pan, freq, sustain, accelerate, detune, voice|
	var sound, env, glide;
	env = EnvGen.ar(Env.linen(0.05, 0.8, 0.15), timeScale:sustain, doneAction:2);
	glide = Line.kr(1, 1+accelerate, sustain);
	sound = Splay.ar(Pulse.ar(freq*[-1*detune/100+0.99,detune/100+1.01]*glide, voice/3+0.5, mul:0.7), 0.3, levelComp:false);
	sound = 0.5 * LPF.ar(sound, 8000);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\super1, {|out, pan, freq, sustain, voice=0|
	var sound, env, fenv, mod;
	env = EnvGen.ar(Env.linen(0.2, 0.6, 0.2), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.1, 2.0, 1, [1,-1]), timeScale:sustain);
	mod = Lag.kr(LFPulse.kr(8.0/sustain, width:0.2).range(0.02,1), 0.1);
	sound = Splay.ar(VarSaw.ar(freq*[0.99,1.01], [0,0.5], 0.7), 0.3, levelComp:false);
	sound = 0.5 * LPF.ar(sound, (freq*12*fenv*mod+280));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// interesting pitch changes
SynthDef(\super2, {|out, pan, freq, sustain, speed|
	var sound, env, fenv, mod1, mod2;
	mod1 = LFPulse.kr(1.0*speed, 0.5, mul:4) + LFPulse.kr(2.0*speed, 0.25, mul:2) + LFPulse.kr(4.0*speed, 0, mul:1);
	mod1 = 2.0 ** (mod1/4.0);
	mod2 = Lag.kr(LFPulse.kr(8.0*speed, width:0.33).range(0.02,1), 0.1);
	env = EnvGen.ar(Env.linen(0.2, 0.6, 0.2), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.1, 1.0, 1, [1,-1]), timeScale:sustain);
	sound = Lag.kr(mod2, 0.5)*1.2*Splay.ar(VarSaw.ar(mod1*freq*[0.99,1.01], [0,0.5], 0.7), 0.3, levelComp:false);
	sound = LPF.ar(Mix.ar(VarSaw.ar(freq * [0.75, 1.0, 1.5, 2.0], 0, [0.4, 0.3 ,0.2, 0.1], mul:0.5)), freq*8*fenv*mod2+1) + sound;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// screechy fm
SynthDef(\super3, {|out, pan, freq, sustain, speed|
	var sound, env, fenv, mod1, mod2, ff, ww;
	env = EnvGen.ar(Env.linen(0.2, 0.6, 0.2), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.1, 2.0, 1, [1,-1]), timeScale:sustain);
	ff = freq * Mix.ar(Pulse.ar(freq / [1.1,2.2,3.3], 0.5).exprange(0.9,1.0/0.9));
	ww = Mix.ar(Pulse.ar([1,2,3,4]*5.0, 0.5).range(0.4,0.6));
	sound = Pulse.ar(ff, ww);
	sound = Mix.ar(RLPF.ar(sound, freq * fenv * [1,2,4,13] + 1, 0.5));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// I like this one
// voice [-1,1]
SynthDef(\super4, {|out, pan, freq, sustain, voice, pitch1|
	var sound, env, fenv, mod1, mod2;
	env = EnvGen.ar(Env.linen(0.1, 0.7, 0.2, 1, [3,-3]), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.2, 2.0, 1, [4,0]), timeScale:sustain);
	sound = LagUD.ar(Pulse.ar(freq, Line.ar(0.5,0.3,sustain)+(voice/0.7)), [5,1]/4000, [1,5]/4000);
	mod1 = Lag.ar(ToggleFF.ar(sound)*2-1, 1/3000);
	mod2 = Fold.ar(Fold.ar(DelayN.ar(sound, 0.2, 0.001))*2-1)*2-1;
	sound = (sound + mod1 + mod2)*0.2;
	sound = RHPF.ar(RLPF.ar(sound, 2024.0*fenv.linexp(0,1,10**(pitch1-1),1), 1/Line.ar(1,4,sustain)), 64.0, 1/3);
	sound = Splay.ar(sound, 0.7);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\super5, {|out, pan, freq, sustain, speed, detune, accelerate, voice, pitch1, slidedelay|
	var sound, env, fenv, mod1, mod2, basefreq,det, pitchenv;
	pitchenv = EnvGen.ar(Env.pairs([[0,1],[slidedelay,1],[1, 1+accelerate]], 0), timeScale:sustain);
	// basefreq = speed * freq * Line.kr(1, 1+accelerate, sustain);
	basefreq = speed * freq * pitchenv;
	det = [0.005, - 0.005] * (detune+1) + 1.0;
	env = EnvGen.ar(Env.linen(0.0, 0.8, 0.2, 1, [3,-3]), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.001, 2.0, 1, [4,0]), timeScale:sustain);
	sound = LagUD.ar(Pulse.ar(basefreq*det, Line.ar([0.7,0.0],0.3,sustain)+(voice/0.7)), [5,3,1]/4000, [1,3,5]/4000);
	mod2 = Fold.ar(Fold.ar(DelayN.ar(sound, 0.2, 0.001))*2-1)*2-1;
	sound = mod2;
	sound = RHPF.ar(RLPF.ar(sound, 2024.0*fenv.linexp(0,1,10**(pitch1-1.2),1), 1/Line.ar(2,4,sustain)), freq, 1/5);
	sound = Splay.ar(sound, 0.4);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;


SynthDef(\superd, {|out, pan, freq, sustain|
	var sound, env, fenv, lfreq, lgain, lpan, lag, locals;
	env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.02, 2, 1, [1,-1]), timeScale:sustain);
	sound = Splay.ar(VarSaw.ar(freq*[0.99,1.01], [0,0.2], 0.98), 0.4, levelComp:false);
	sound = 0.5 * LPF.ar(sound, freq*10*fenv+800);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\dronec, {|n=0, gain=1, pan=0.5, speed, sustain|
	Out.kr(dronebus, [n, gain, pan, speed, sustain]);
}).add;

SynthDef(\drone, {|out, pan, freq, sustain|
	var sound, env, fenv, lfreq, lgain, lpan, lag, locals;
	env = EnvGen.ar(Env.linen(0.005, 0.99, 0.005), timeScale:sustain, doneAction:2);
	locals = In.kr(dronebus, 5);
	fenv = EnvGen.ar(Env.perc(0.02, 2, 1, [1,-1]), gate:Changed.kr(locals[0]), timeScale:locals[4]);
	lag = 0.5 * locals[4] / locals[3];
	lfreq = freq * Lag.kr(2.0 ** (locals[0]/12), lag);
	lgain = 1.0 * Lag.kr(locals[1], lag);
	lpan = pan + Lag.kr(locals[2], lag);
	sound = Splay.ar(VarSaw.ar(lfreq*[0.99,1.01], [0,0.2], 0.98), 0.4, levelComp:false);
	sound = LPF.ar(sound, freq*10*fenv+800);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, lpan, env*lgain));
}).add;

SynthDef(\superf, {|out, pan, freq, sustain|
	var ctls, mods, chans, env;
	env = EnvGen.ar(Env.linen(0.01, 0.95, 0.04), timeScale:sustain, doneAction:2);
	ctls = [
        // freq, phase, amp
        [freq, 0, 1],
        [freq, 0.5, 1],
        [freq *4 , 0, 1],
        [freq * 33/32, 0, 1],
        [LFNoise2.kr(0.5).exprange(3, 800), 0, 1],
        [LFNoise2.kr(0.5).exprange(0.3, 10), 0, 1]
    ];
    mods = [
		[0.2, 0, 1,  LFNoise1.kr(0.5).exprange(0.1,1), 0, 0],
		[0, 0.2, 1,  LFNoise1.kr(0.5).exprange(0.1,1), 0, 0],
		[0, 0, 0.2, 0.5, 0, 0.1],
		[0.1, 0.1, 2, 0, 0, 0.1],
        0!6,
		[0, 0, 3, 0, 1, 0]
    ];
	chans = FM7.ar(ctls, mods).slice([0, 1]) * -12.dbamp;
	OffsetOut.ar(out, DirtPan.ar(chans, ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superfff, {|out, pan, freq, sustain|
	var sound;
	var aenv = EnvGen.ar(Env.perc(0.01, 0.99, 1, -1), timeScale:sustain, doneAction:2);
	sound = SinOsc.ar(freq);
	sound = ringfunc.value(sound, SinOsc.ar(freq-40));
	sound = tanh(sound/2.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

// FUTURE???
SynthDef(\superpsaw, {|out, pan, freq, sustain, detune=0, voice=0|
	var sound, mod, aenv, fenv;
	aenv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, 'lin'), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.1, 0.9, 1, -1), timeScale:sustain);
	sound = Splay.arFill(4, {|n| VarSaw.ar(freq*(0.01*n+0.985)*(detune/12+1), Rand(0,1), 0.01+voice)}, 0.4);
	sound = RLPF.ar(sound, freq*(5+voice)*fenv, 1.5);
	sound = sin(sound*2)/1.6;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

// trying some phase sync stuff
// kind of brassy?
SynthDef(\supersync, {|out, pan, freq, sustain|
	var sound, mod, aenv, fenv;
	aenv = EnvGen.ar(Env.linen(0.1, 0.8, 0.1, 1, 'lin'), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.2, 0.7, 1, -1), timeScale:sustain);
	sound = Splay.ar(SyncSaw.ar(freq, [1800, 803, 500, 499, 800, 1810]), 0.5);
	sound = sound + ([0.3,-0.3] * DelayC.ar(sound, 0.1, Line.ar(1,0.5,sustain)*0.005));
	sound = RLPF.ar(sound, clip(freq*7*fenv, 20, 15000), 1.5);
	sound = sin(sound*2)/2;
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv));
}).add;

// build in some distortion?
SynthDef(\superdrop, {|out, sustain=1, pan, freq, accelerate=0, pitch1=4, voice=0,lfo=0|
	var sound, basefreq, aenv, fenv, menv, ind, m1, m2, filtrange;
	basefreq = freq * Line.kr(1, 1+accelerate, sustain);
	aenv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, 'lin'), timeScale:sustain, doneAction:2);
	menv = XLine.ar(4, 1, sustain/3);
	sound = Saw.ar(basefreq * menv * [0.99, 1, 1.01]);
	sound = Splay.ar(sound);
	sound = sound * Pulse.ar(4*basefreq*menv, 0.3);
	sound = tanh(1.5*sin(1.5*sound));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv))
}).add;

// maybe turn into a nice pad and rename
SynthDef(\superdub5, {|out, sustain=1, pan, freq, accelerate=0, pitch1=4, voice=0,lfo=0|
	var sound, basefreq, aenv, fenv, menv, ind, m1, m2, filtrange;
	aenv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, 'lin'), timeScale:sustain, doneAction:2);
	menv = EnvGen.ar(Env.linen(0.3, 0.2, 0.5), timeScale:sustain);
	basefreq = freq * Line.kr(1, 1+accelerate, sustain);
	m1 = SinOsc.ar(basefreq*2) * basefreq/8;
	m2 = SinOsc.ar(basefreq + m1*4) * basefreq*2 * menv;
	sound = Splay.ar(VarSaw.ar(basefreq+m2 * [0.99,1,1.01], 0, 0.2*menv+0.1));
	sound = (sound*(50*voice+5)).clip(-1,1)*0.5;
	sound = HPF.ar(LeakDC.ar(sound), 60);
	sound = 0.5*LFTri.ar(basefreq) + sound;
	sound = sin(2*sound);
	filtrange = clip(menv*basefreq*12+1200, 2, 20000);
	sound = LPF.ar(sound, LFTri.kr(pitch1).range(filtrange*(1-lfo), filtrange));
	OffsetOut.ar(out, DirtPan.ar(sound*aenv, ~dirt.numChannels, pan, 1))
}).add;

// pops a bit, could be nice if fixed
SynthDef(\superdub6, {|out, sustain=1, pan, freq, accelerate=0, pitch1=4, voice=0,lfo=0,detune=0.008|
	var sound, basefreq, aenv, fenv, menv, ind, m1, m2, filtrange, detarr;
	aenv = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, 'lin'), timeScale:sustain, doneAction:2);
	menv = EnvGen.ar(Env.linen(0.4, 0.6, 0.0, 1, 1), timeScale:sustain);
	basefreq = 2**(Lag.kr(In.kr(notebus,1),sustain));
	ReplaceOut.kr(notebus, log2(freq));
	basefreq = basefreq * Line.kr(1, 1+accelerate, sustain);
	detarr = Array.interpolation(3,1-detune,1+detune);
	sound = Splay.ar(Pulse.ar(basefreq * detarr, detarr-0.5)) + Splay.ar(VarSaw.ar(basefreq, 0, [0.1,0.2,0.3])* 0.5);
	sound = sound - CombN.ar(sound, 0.2, 0.010*Line.kr(1,1.5,sqrt(sustain)), 0.1);
	sound = LPF.ar(sound, menv*3000);
	sound = sin(sound*20/sqrt(freq));
	sound = HPF.ar(LeakDC.ar(sound), 60);
	sound = BPeakEQ.ar(sound, XLine.kr(30, 3000, 1), 0.1, -20);
	sound = BPeakEQ.ar(sound, XLine.kr(5000, 60, 1), 0.15, -20);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv))
}).add;

// not what the name says
SynthDef(\superacid, {|out, speed=1, sustain=1, decay=0, pan, freq, accelerate=0, voice=0.0, slide=0,
	pitch1=500, pitch2=1500|
	var sound, basefreq, aenv, fenv, glide;
	aenv = EnvGen.ar(Env.perc(0.01, 1, 1, 'lin'), timeScale:sustain, doneAction:2);
	fenv = EnvGen.ar(Env.perc(0.01, 1+decay, 1, 'lin'), timeScale:sustain);
	glide = EnvGen.ar(Env.perc(0.05, 0.5, 1, \lin), timeScale:sustain) * (-1*slide/4) + 1;
	basefreq = freq * glide * Line.kr(1, 1+accelerate, sustain);
	sound = VarSaw.ar(basefreq, 0) - VarSaw.ar(basefreq, voice/2+0.5);
	sound = 2.0*RLPFD.ar(sound, pitch2*fenv+pitch1, 0.5, 1);
	sound = 0.5*tanh(10.0*sound);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, aenv))
}).add;

SynthDef(\superwobble, {|out, sustain=1, pan, speed=1, accelerate, freq, decay=0,
	  pitch1=4000, lfo=0.5, pitch2=4, slide=0|
	var env = EnvGen.ar(Env.pairs([[0,0],[0.07,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var glide = EnvGen.ar(Env.perc(0.05, 0.2, 1, \lin), timeScale:sustain) * (-1*slide/4) + 1;
	var basefreq = freq * glide * Line.kr(1, 1+accelerate, sustain) * [0.99, 1.01];
	var sound = LPF.ar(Pulse.ar(basefreq), basefreq*4) + Saw.ar(1.99*basefreq) + Saw.ar(3.98*basefreq);
	sound = 0.6*LPF.ar(sound, pitch1*SinOsc.kr(pitch2/(sustain),3.5).exprange(1,10.0**(-2.0*lfo)));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// pulse?
SynthDef(\superpulse, {|out, sustain=1, pan, speed=1, accelerate, freq, decay=0, slide=1 |
	var env = EnvGen.ar(Env.pairs([[0,0],[0.07,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var basefreq = freq * Line.kr(1, 1+accelerate, sustain) * [0.99, 1.01];
	var sound = Blip.ar(basefreq, 64) + Impulse.ar(basefreq) + Saw.ar(basefreq);
	sound = BHiShelf.ar(sound, 1200, 10, -8);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// original idea - http://www.attackmagazine.com/technique/synth-secrets/detuned-pad/
SynthDef(\superzzz, {|out, sustain=1, pan, freq, detune=1  |
	var sound, env, freqs, osc1, osc2;
	env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05), timeScale:sustain, doneAction:2);
	freqs = freq * ([0, 0.01*Rand(-1,1), 0.009*Rand(-1,1), 0.011*Rand(-1,1)]*detune + 1.0);
	osc1 = DelayC.ar( LFSaw.ar(freqs, Rand(0,2pi)) , 0.2, freqs.reciprocal * SinOsc.ar(Rand(3,4), Rand(0,2pi)).range(0.9,1));
	osc2 = DelayC.ar( LFSaw.ar(freqs/2*Rand(0.99,1.01), Rand(0,2pi)), 0.2, freqs.reciprocal * SinOsc.ar(Rand(2,3), Rand(0,2pi)).range(0.9,1));
	sound = BLowPass4.ar(osc2, SinOsc.ar(Rand(2,4)).range(800,900), 1) + osc1;
	sound= 0.7*tanh(0.3*Mix.ar(sound));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// trying out some synth voice stuff, right now starts with 'a' and glides to vowel with formants at pitch1,pitch2 (default 'i')
SynthDef(\supervoice, {|out, sustain=1, pan, freq, pitch1=240, pitch2=2400|
	var sound, env, p1, p2;
	env = EnvGen.ar(Env.linen(0.1, 0.8, 0.1), timeScale:sustain, doneAction:2);
	sound = Impulse.ar(freq);
	p1 = XLine.kr(850, pitch1, sustain*0.5);
	p2 = XLine.kr(1610, pitch2, sustain*0.5);
	sound = 0.5*DynKlank.ar(`[[p1, p2], nil, nil], sound, decayscale:0.01);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

// write a signal into a delay, tap it at multiple times
// I think this messes up if more than one is playing at a time
SynthDef(\superbuf, {|out, sustain=1, pan, freq|
	var sound, env, tapPhase, tap1, tap2, tap3, sl, sr;
	// env = EnvGen.ar(Env.perc(0.005, 1, 1, 1), timeScale:sustain, doneAction:2);
	env = EnvGen.ar(Env.linen(0.005, 0.8, 0.195, 1, 1), timeScale:sustain, doneAction:2);
	sound = Mix.ar(VarSaw.ar(freq, [0, 0.5, 1], Line.kr(0,1,sustain)));
    tapPhase = DelTapWr.ar(synthbuf, sound);
    #tap1, tap2, tap3 = DelTapRd.ar(synthbuf, tapPhase,
		[0.1, 0.27, 0.303] * Line.kr(0.48,0.52,sustain) * 0.3 * sustain,      // tap times
        1,                      // no interp
        [1.0, 0.6, 0.4]         // muls for each tap
        );
	sl = sound+tap2;
	sr = tap1 + tap3;
	OffsetOut.ar(out, DirtPan.ar(Splay.ar([sl, sr],0.4, 0.3), ~dirt.numChannels, pan, env));
}).add;

SynthDef(\supercross, {|out, speed=1, sustain=1, decay=0, pan, freq, accelerate=0, voice=0.0, detune=0.0,
	  pitch1=1, pitch2=2, vcoegint=0|
	var env = EnvGen.ar(Env.pairs([[0,0],[0.03,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var basefreq1 = pitch1 * freq * Line.kr(1, 1+accelerate, sustain);
	var basefreq2 = pitch2 * freq * Line.kr(1, 1+accelerate, sustain);
	var sound, sa, sb, loop, rlo, rhi;
	rlo = 1.0 - (0.9 * vcoegint);
	rhi = 1.0 + (0.9 * vcoegint);
	loop = LocalIn.ar(1);
	basefreq1 = clip(basefreq1 * loop.range(rlo,rhi), 2, 20000); // FM mod from osc 2
	sa = SelectX.ar(voice, [
		VarSaw.ar(basefreq1, 0, 0.5) - VarSaw.ar(basefreq1+detune, 0, 0.2),
		SinOsc.ar(basefreq1+detune,0.1) * loop.range(rlo,1), // ring mod for sine,
		LFTri.ar(basefreq1, 0) + LFTri.ar(basefreq1+detune, 0.1) * 0.5,
		Pulse.ar(basefreq1+detune, LPF.ar(loop.range(rlo/2,rhi/2), 50)) * 0.5 // mod pulse width for square
	]);
	basefreq2 = clip(basefreq2 * sa.range(rlo,rhi), 2, 20000); // FM mod from osc 1
	sb = SelectX.ar(voice, [
		VarSaw.ar(basefreq2-detune, 0.2, 0.2) - VarSaw.ar(basefreq2-detune, 0.2, 0.3),
		SinOsc.ar(basefreq2-detune,0.3) * sa.range(rlo,1), // ring mod for sine
		LFTri.ar(basefreq2-detune, 0.3) + LFTri.ar(basefreq2-detune, 0.2) * 0.5,
		Pulse.ar(basefreq2-detune, LPF.ar(sa.range(rlo/2,rhi/2), 50) ) * 0.5
	]);
	LocalOut.ar(DelayN.ar(sb,0.2, Line.ar(0,0.5,sustain)/basefreq1));
    sound = sa+sb;
	sound = 0.5*LPF.ar(sound, XLine.ar(1,0.01,sustain, 12000));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

// probably way too complicated, this synth has it's own set of filters, controllable with new parameters
// voice: 0 - saw, 1 - square (can go past 1 for noisy overdrive)
// slide: initial pitch glide, can be used to fake portamento
// decay: 0 is minimal decay, 1 will quickly decay to silence (you can also use the global release param for a different shape)
// sfcutoff, sfresonance, sfenv, sfattack, sfrelease: filter params for this synth only
//    the envelope shape for this synth is different from the global filter envelope
// pitch1: advanced params for tweaking lowpass and bandpass frequencies

// something I still don't like - CLEAN UP AND FIX
SynthDef(\super302, {|out, speed=1, sustain=1, decay=0, pan, freq, accelerate=0, voice=0.0, slide=0,
	pitch1=1,sfattack=0, sfrelease=0, sfenv=0, sfcutoff=1000, sfresonance=0|
	var sound, glide, basefreq, env, env2, resq, loresq;
	env = EnvGen.ar(Env.new([1e-6,1,(1-decay)*0.5,1e-6], [0.03, 0.9, 0.07], 'exp'), timeScale:sustain, doneAction:2);
	// env2= EnvGen.ar(Env.perc(sfattack, sfrelease, 1, [-4,4]));
	env2 = EnvGen.ar(Env.linen(sfattack, 0, sfrelease));
	glide = EnvGen.ar(Env.perc(0.05, 0.5, 1, \lin), timeScale:sustain) * (-1*slide/4) + 1;
	basefreq = freq * glide * Line.kr(1, 1+accelerate, sustain);
	sound = tanh(VarSaw.ar(basefreq, 0, 0.98)+PinkNoise.ar(0.01*exp(voice))*(voice*50+1));
	resq = 1.0 + (26 * sfresonance);
	// loresq = 1.0 + (26*4.67*sfresonance);
	loresq = 1.0 + (26*sfresonance);
	// sound = BPF.ar(sound, clip(sfcutoff/10*pitch2+(sfenv/10*env2*pitch2), 20,11000),
	// rq:2.9-(2.8*vcfegint));
	// sound = sound * (1.2 + (1.2*vcfegint));
	sound = BMoog.ar(sound, clip(sfcutoff+(sfenv*env2)/2, 20, 11000), q:sfresonance, mode:2, saturation:0.99);
	sound = RHPF.ar(sound, clip(sfcutoff/100*pitch1+(sfenv/10000*env2*pitch1), 8,8000), rq:1/loresq);
	sound = RLPF.ar(sound, clip(sfcutoff+(sfenv*env2), 20, 11000), rq:1/clip(resq*1000/sfcutoff,1,52));
	//sound = ((sfresonance * sound)**3 + sound) / (max(1,sfresonance)**3);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\superlagcomp, {|out, speed=1, sustain=1, decay=0, pan, freq, accelerate=0, voice=0.2|
	var env = EnvGen.ar(Env.pairs([[0,0],[0.03,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
	var sound, sa,sb, sl, sr;
	sa = Saw.ar(basefreq) + Saw.ar(basefreq*1.011);
	sb = Saw.ar(clip(basefreq*4.0+(freq/5*sa),5,20000)) + Saw.ar(clip(basefreq*4.021*(1+voice)+(freq/5*sa), 5, 20000));
	sound = LPF.ar(sa > sb, clip(freq*(voice+1),5,20000));
	sa = sa * sb.range(0.5,1);
	sound = (sound * sa) + ((1-sound) * sb) + BlitB3Tri.ar(basefreq, 0.99, 0.99, 0.2);
	sl = 0.5 * sound;
	sr = 0.5 * DelayN.ar(sound, 0.2, Line.ar(0.01,0.02,sustain));
	OffsetOut.ar(out, DirtPan.ar([sl,sr], ~dirt.numChannels, pan, env));
}).add;

SynthDef(\superphase, {|out, speed=1, sustain=1, decay=0, pan, freq, accelerate=0, voice=0 |
	var env = EnvGen.ar(Env.pairs([[0,0],[0.07,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
	var fadj = [0.005, 0.007] * (voice+1) + 1.0;
	var fadj2 = 1.0 - ([0.005, 0.007] * (voice+1));
	var sound = Saw.ar(basefreq*fadj[0]) - DelayC.ar(Saw.ar(basefreq*fadj[1]), 0.2, SinOsc.kr(0.5).range(0.2,0.4)/basefreq);
	var fenv = EnvGen.ar(Env.perc(0.01, 2, 1, 2), timeScale:sustain);
	sound = sound + Saw.ar(basefreq*fadj2[0]) - DelayC.ar(Saw.ar(basefreq*fadj2[1]), 0.2, SinOsc.kr(0.5).range(0.2,0.4)/basefreq);
	sound = sound + PMOsc.ar(basefreq, basefreq*1.01, Line.kr(6.28,0));
	sound = sound - BAllPass.ar(sound, XLine.kr(4400,44,sustain), 2);
	sound = MoogFF.ar(sound/2, fenv*XLine.kr(10000, 500/speed+(basefreq/2), sustain), 1);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add;

SynthDef(\superblip, {|out, sustain=1, pan, freq|
	var env = EnvGen.ar(Env.perc(0.050, 0.900, 1, -2), timeScale:sustain, doneAction:2);
	var sound = Pulse.ar(freq, Line.kr(0,1,sustain), 0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;


// experimental
SynthDef(\fx, {|out, freq, pan, sustain|
	var sound, env;
	sound = In.ar(fxbus, ~dirt.numChannels);
	env = EnvGen.ar(Env.linen(0.1, 0.7, 0.1), timeScale:sustain, doneAction:2);
	sound = Mix.ar(DelayL.ar(sound, 2.0, [0.3, 0.5, 0.7, 0.9]));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
//// CUSTOM EFFECTS //////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

~dirt.addModule('lpg', {|dirtEvent| dirtEvent.sendSynth("dirt_lpg" ++ ~dirt.numChannels,
[lpg: ~lpg, lpga: ~lpga, lpgr: ~lpgr, lpgg: ~lpgg, lpgres: ~lpgres, out: ~out])}, {~lpg.notNil});
SynthDef("dirt_lpg"++~dirt.numChannels, {|out, lpg, lpga=0.001, lpgr=0.010, lpgg=1.0, lpgres=0|
	var in = In.ar(out, ~dirt.numChannels);
	// var gate = Amplitude.ar(in*lpgg, lpga, lpgr);
	var gate = LagUD.ar(Amplitude.ar(in*lpgg, 0.001, 0.001), lpga, lpgr);
	var filt = RLPF.ar(in, gate.expexp(-60.dbamp, 0.dbamp, 20, 20000), 1.0 - lpgres);
	ReplaceOut.ar(out, SelectX.ar(lpg, [in, filt]));
}).add;

~dirt.addModule('whammy', {|dirtEvent| dirtEvent.sendSynth("dirt_whammy" ++ ~dirt.numChannels,
[whammy: ~whammy, whammyshift: ~whammyshift, whammyfreq: ~whammyfreq, whammydelay: ~whammydelay, sustain: ~sustain, out: ~out])}, {~whammy.notNil});
SynthDef("dirt_whammy"++~dirt.numChannels, {|out, whammy, whammyshift, whammyfreq, whammydelay, sustain|
	var in = In.ar(out, ~dirt.numChannels);
	var transpose = whammyshift + (12.0 * (whammyshift < 1e-6));
	var grainsize = 1.0 / (whammyfreq + (5.7 * (whammyfreq < 1e-6))); // 0.075 is a bit faster
	var grainfreq = XLine.ar(transpose.midiratio * 1.02, transpose.midiratio, sustain) / grainsize; // transpose / grainsize
	var deltime = whammydelay + (0.02 * (whammydelay < 1e-6)); // 0.05 down to zero?
	var sig = in;
	sig = DelayC.ar(sig, 1, LFSaw.ar(grainfreq, [1,0]) * grainsize / (-2.0) + deltime);
	sig = sig * SinOsc.ar(grainfreq, [-1.0,1.0]*pi/2).linlin(-1,1,0,1);
	sig = LeakDC.ar(sig);
	ReplaceOut.ar(out, SelectX.ar(whammy/2.0, [in, sig]));
}).add;

~dirt.addModule('schmidt', {|dirtEvent| dirtEvent.sendSynth("dirt_schmidt" ++ ~dirt.numChannels,
[schmidt: ~schmidt, out: ~out])}, {~schmidt.notNil});
SynthDef("dirt_schmidt"++~dirt.numChannels, {|out, schmidt|
	var in = In.ar(out, ~dirt.numChannels);
	var sig = in * Schmidt.ar(in, -0.1, 0.1);
	ReplaceOut.ar(out, SelectX.ar(schmidt, [in, sig]));
}).add;

~dirt.addModule('zpulse', {|dirtEvent| dirtEvent.sendSynth("dirt_zpulse" ++ ~dirt.numChannels,
[zpulse: ~zpulse, out: ~out])}, {~zpulse.notNil});
SynthDef("dirt_zpulse"++~dirt.numChannels, {|out, zpulse|
	var in = In.ar(out, ~dirt.numChannels);
	var sig = Blip.ar(ZeroCrossing.ar(in), numharm:5, mul:Amplitude.ar(in, 0,0));
	ReplaceOut.ar(out, SelectX.ar(zpulse, [in, sig]));
}).add;

~dirt.addModule('enc', {|dirtEvent| dirtEvent.sendSynth("dirt_enc" ++ ~dirt.numChannels,
[enc: ~enc, out: ~out])}, {~enc.notNil});
SynthDef("dirt_enc"++~dirt.numChannels, {|out, enc|
	var sig = In.ar(out, ~dirt.numChannels);
	/*var fs = [250, 300, 450, 610, 810, 1100, 1300, 1700];*/
	var fs = [60, 270, 200, 350] *.x [3, 7, 11, 17, 29, 41];
	var cutoff = clip(fs/100, 30, 60);
	var amps = LPF.ar(LPF.ar(Mix.ar(sig) * SinOsc.ar(fs), cutoff), cutoff);
	var recon = Mix.ar(2.0 * amps * SinOsc.ar(fs));
	ReplaceOut.ar(out, SelectX.ar(enc, [sig, recon]));
}).add;

~dirt.addModule('match', {|dirtEvent| dirtEvent.sendSynth("dirt_match" ++ ~dirt.numChannels,
[match: ~match, matchf: ~matchf, matchw: ~matchw, out: ~out])}, {~match.notNil});
SynthDef("dirt_match"++~dirt.numChannels, {|out, match, matchf=440, matchw=20|
	var in = In.ar(out, ~dirt.numChannels);
	var sig = LocalIn.ar(1);
	var adj = 1.0 * LPF.ar(sig * in, matchf*1.5);
	sig = SinOsc.ar(adj * matchw + matchf);
	LocalOut.ar(sig * 0.99);
	sig = SelectX.ar(match, [in, sig]);
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('median', {|dirtEvent| dirtEvent.sendSynth("dirt_median" ++ ~dirt.numChannels,
[median: ~median, out: ~out])}, {~median.notNil});
SynthDef("dirt_median"++~dirt.numChannels, {|out, median|
	ReplaceOut.ar(out, Median.ar(Select.kr(median*15, (0..15) * 2 + 1), In.ar(out, ~dirt.numChannels)));
}).add;

~dirt.addModule('comb', {|dirtEvent| dirtEvent.sendSynth("dirt_comb" ++ ~dirt.numChannels,
[comb: ~comb, combd: ~combd, combdiff: ~combdiff, out: ~out])}, {~comb.notNil});
SynthDef("dirt_comb"++~dirt.numChannels, {|out, comb, combd, combdiff|
	var sig= In.ar(out, ~dirt.numChannels);
	sig = sig + DelayL.ar(sig, 0.2, [combd/100+1e-4, (combd+combdiff)/100+1e-4], mul:comb);
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('chunk', {|dirtEvent| dirtEvent.sendSynth("dirt_chunk" ++ ~dirt.numChannels,
[chunk: ~chunk, chunksharp: ~chunksharp, chunkspread: ~chunkspread, out: ~out])}, {~chunk.notNil});
SynthDef("dirt_chunk"++~dirt.numChannels, {|out, chunk, chunksharp, chunkspread|
	var sig = In.ar(out, ~dirt.numChannels);
	var scale = 2**(8-(8*(chunk**0.25)));
	var sharp = chunksharp + 2.0;
	sig = Array.fill(4, {|i| DelayL.ar(sig, 0.2, chunkspread*i/100)});
	sig = round(sig, 1/scale) + (sign(sig) * abs(sig - round(sig,1/scale))**sharp);
	sig = Mix.ar(sig) / (4-(4*chunkspread).clip(0,3));
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('chorus2', {|dirtEvent| dirtEvent.sendSynth("dirt_chorus2" ++ ~dirt.numChannels,
[chorus2: ~chorus2, sustain: ~sustain, out: ~out])}, {~chorus2.notNil});
SynthDef("dirt_chorus2"++~dirt.numChannels, {|out, chorus2, sustain|
	var sig = In.ar(out, ~dirt.numChannels);
	var c1 = DelayN.ar(sig, 2, Sweep.ar(Impulse.ar(0), chorus2/50));
	var c2 = DelayN.ar(sig, 2, 0.001+Sweep.ar(Impulse.ar(0), chorus2/60));
	sig = Splay.ar([DelayN.ar(c2, 0.2, 0.010*chorus2), c1, sig, c2, DelayN.ar(c1, 0.2, 0.015*chorus2)], chorus2);
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('chorus', {|dirtEvent| dirtEvent.sendSynth("dirt_chorus" ++ ~dirt.numChannels,
[chorus: ~chorus, sustain: ~sustain, out: ~out])}, {~chorus.notNil});
SynthDef("dirt_chorus"++~dirt.numChannels, {|out, chorus, sustain|
	var sig = In.ar(out, ~dirt.numChannels);
	sig = (chorus > 0) * DelayN.ar(sig, sustain/5, Line.ar(0,chorus*sustain/100, sustain) + SinOsc.ar(0.3,mul:3e-4)) + sig;
	sig = sig / ((chorus > 0) * sqrt(2) + ((chorus < 1e-6) * 1));
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('digidest', {|dirtEvent| dirtEvent.sendSynth("dirt_digidest" ++ ~dirt.numChannels,
[digidest: ~digidest, sustain: ~sustain, out: ~out])}, {~digidest.notNil});
SynthDef("dirt_digidest"++~dirt.numChannels, {|out, digidest, sustain|
	var sig = In.ar(out, ~dirt.numChannels);
	digidest = digidest/2;
	sig = DelayN.ar(sig, 1, Line.ar(0,digidest*sustain, sustain).round(1/15));
	sig = Latch.ar(sig, Impulse.ar(LinExp.ar(Line.ar(4,1, sustain*digidest.linexp(0,1,10,0.1) ).round(0.2), 1,4, 20, 20000)));
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('djfilt', {|dirtEvent| dirtEvent.sendSynth("dirt_djfilt" ++ ~dirt.numChannels,
[djfilt: ~djfilt, out: ~out])}, {~djfilt.notNil});
SynthDef("dirt_djfilt"++~dirt.numChannels, {|out, djfilt|
	var sig = In.ar(out, ~dirt.numChannels);
	var rc = tan(pi * 800 / 44100);
	var octaves = (djfilt - 0.5) * 2 * 3;
	var r = rc / (2 ** octaves);
	var a = [3,1] * pi / 8;
	var zd = 1 + (r * r) + (2 * r * cos(a));
	var pd = 1 + (rc * rc) + (2 * rc * cos(a));
	var zx = (1 - (r*r)) / zd;
	var px = (1 - (rc*rc)) / pd;
	var zy = 2 * r * sin(a) / zd;
	var py = 2 * rc * sin(a) / pd;
	var w = (octaves < 0) * 2 - 1;
	var gain1 = (1 - (2 * w * zx[0]) + sumsqr(zx[0], zy[0])) / (1 - (2 * w * px[0]) + sumsqr(px[0], py[0]));
	var gain2 = (1 - (2 * w * zx[1]) + sumsqr(zx[1], zy[1])) / (1 - (2 * w * px[1]) + sumsqr(px[1], py[1]));
	var gain = gain1 * gain2;
	sig = SOS.ar(sig, 1, -2 * zx[0], sumsqr(zx[0], zy[0]), -2 * px[0], sumsqr(px[0], py[0]), mul:1/gain);
	sig = SOS.ar(sig, 1, -2 * zx[1], sumsqr(zx[1], zy[1]), -2 * px[1], sumsqr(px[1], py[1]));
	// sig = SOS.ar(sig, 1, -2 * px[0], sumsqr(px[0], py[0]), -2 * zx[0], sumsqr(zx[0], zy[0]), mul:1/gain);
	// sig = SOS.ar(sig, 1, -2 * px[1], sumsqr(px[1], py[1]), -2 * zx[1], sumsqr(zx[1], zy[1]));
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('vocode', {|dirtEvent| dirtEvent.sendSynth("dirt_vocode" ++ ~dirt.numChannels,
	[vocode: ~vocode, vocoden: ~vocoden, out: ~out])}, {~vocode.notNil});
SynthDef("dirt_vocode"++~dirt.numChannels, {|out, vocode, vocoden|
	var mod = In.ar(out, ~dirt.numChannels);
	var note = (vocoden+60).midicps;
	var car = VarSaw.ar(note, 0, 0.5) - VarSaw.ar(note*1.01, 0, Line.ar(0.3,0.7,1)) + Pulse.ar(note*0.99, 0.2);
	var sig = 5*Vocoder.ar(car, mod, 64, low:200, high:4000, q:0.01, hpf:6000, hpfscal:0.02);
	ReplaceOut.ar(out, SelectX.ar(vocode, [mod,sig]));
}).add;

~dirt.addModule('fshiftalt', {|dirtEvent| dirtEvent.sendSynth("dirt_fshiftalt" ++ ~dirt.numChannels,
	[fshift2: ~fshift2, fshiftphase2: ~fshiftphase2, fshiftnote2: ~fshiftnote2, freq: ~freq, out: ~out])}, {~fshift2.notNil});
SynthDef("dirt_fshiftalt"++~dirt.numChannels, {|out, fshift2, fshiftphase2, fshiftnote2, freq|
	var sig = In.ar(out, ~dirt.numChannels);
	var shift = freq*fshiftnote2 + fshift2;
	var s1,s2;
	var modfreq = 3001.0;
	var demodfreq = modfreq + shift;
	// s1 = sig * SinOsc.ar(modfreq, 0);
	// s2 = sig * SinOsc.ar(modfreq, pi/2+fshiftphase2);
	s1 = DiodeRingMod.ar(sig, SinOsc.ar(modfreq, 0));
	s2 = DiodeRingMod.ar(sig, SinOsc.ar(modfreq, pi/2+fshiftphase2));
	s1 = BLowPass4.ar(s1, modfreq);
	s2 = BLowPass4.ar(s2, modfreq);
	// s1 = s1 * SinOsc.ar(demodfreq, 0);
	// s2 = s2 * SinOsc.ar(demodfreq, pi/2+fshiftphase2);
	s1 = DiodeRingMod.ar(s1, SinOsc.ar(demodfreq, 0));
	s2 = DiodeRingMod.ar(s2, SinOsc.ar(demodfreq, pi/2+fshiftphase2));
	// sig = (s1+s2)*1.3;
	sig = (s1+s2)/1.2;
	ReplaceOut.ar(out, sig);
}).add;

// experimental
~dirt.addModule('fxbus', {|dirtEvent| dirtEvent.sendSynth("dirt_fxbus" ++ ~dirt.numChannels,
	[send: ~send, out:~out])}, {~send.notNil});
SynthDef("dirt_fxbus"++~dirt.numChannels, {|out, send=0, sustain|
	var sig,env;
	sig = In.ar(out, ~dirt.numChannels);
	Out.ar(fxbus, sig*send);
	ReplaceOut.ar(out,sig);
}).add;

~dirt.addModule('lpf2', {|dirtEvent| dirtEvent.sendSynth("dirt_lpf2" ++ ~dirt.numChannels,
	[cutoff2: ~cutoff2, freq:~freq, resonance:~resonance, out: ~out])}, {~cutoff2.notNil});
SynthDef("dirt_lpf2"++~dirt.numChannels, {|out, cutoff2=0, resonance, freq|
	var sig;
	sig = In.ar(out, ~dirt.numChannels);
	sig = BLowPass4.ar(sig, freq*(1+cutoff2), resonance.linexp(0, 1, 1, 0.001));
	ReplaceOut.ar(out, sig);
}).add;

~dirt.addModule('amdist', {|dirtEvent| dirtEvent.sendSynth("dirt_amdist" ++ ~dirt.numChannels,
	[amdist: ~amdist, amdistf: ~amdistf, out: ~out])}, {~amdist.notNil});
SynthDef("dirt_amdist"++~dirt.numChannels, {|out, amdist, amdistf|
	var sig, ampmod, freqs;
	sig = In.ar(out, ~dirt.numChannels);
	ampmod = (1.0 + PinkNoise.kr()) * 0.05 * amdist;
	freqs = (amdistf < 1) * 9800 + amdistf + [0,10];
	sig = sig * SinOsc.ar(freqs+PinkNoise.kr(10*amdist)); // modulate
	sig = sig + PinkNoise.ar(ampmod); // add noise
	sig = sig * SinOsc.ar(freqs+PinkNoise.kr(10*amdist)); // demodulate
	ReplaceOut.ar(out, sig);
}).add;

// actually a stereo field distortion now
~dirt.addModule('fmdist', {|dirtEvent| dirtEvent.sendSynth("dirt_fmdist" ++ ~dirt.numChannels,
[fmdist: ~fmdist, fmdistf: ~fmdistf, out: ~out])}, {~fmdist.notNil});
SynthDef("dirt_fmdist"++~dirt.numChannels, {|out, fmdist, fmdistf|
	var dry, wet, lpr, lmr;
	dry = In.ar(out, ~dirt.numChannels);
	lpr = dry[0]+dry[1];
	lmr = dry[0]-dry[1];
	lmr = RLPF.ar(lmr, 800, 0.1);
	lmr = lmr + WhiteNoise.ar(fmdist*0.01);
	lmr = tanh(fmdist*lmr);
	wet = [lpr+lmr, lpr-lmr];
	ReplaceOut.ar(out, SelectX.ar(fmdist, [dry, 0.5*wet]));
}).add;

~dirt.addModule('allpass', {|dirtEvent| dirtEvent.sendSynth("dirt_allpass" ++ ~dirt.numChannels,
[allpass: ~allpass, out: ~out])}, {~allpass.notNil});
SynthDef("dirt_allpass"++~dirt.numChannels, {|out, allpass|
	var dry, wet, rez, imz, zsq, th, mag;
	th = SinOsc.ar(1).range(0,3);
	mag = 0.99;
	rez = mag*cos(th);
	imz = mag*sin(th);
	zsq = (rez*rez) + (imz*imz);
	dry = In.ar(out, ~dirt.numChannels);
	wet = SOS.ar(dry, zsq, -2.0*rez, 1.0, 2.0*rez, -1.0*zsq);
	ReplaceOut.ar(out, SelectX.ar(allpass, [dry, wet]));
}).add;

// general EQ?
~dirt.addModule('sparkle', { |dirtEvent| dirtEvent.sendSynth("dirt_sparkle" ++ ~dirt.numChannels,
			[sparkle: ~sparkle, sparklef: ~sparklef, out: ~out])}, { ~sparkle.notNil});
SynthDef("dirt_sparkle" ++ ~dirt.numChannels, {|out, sparkle, sparklef|
	var signal, freq;
	signal = In.ar(out, ~dirt.numChannels);
	freq = Select.kr(sparklef > 0, [DC.kr(2000), sparklef]);
	signal = BHiShelf.ar(signal, freq, 0.9, sparkle*10);
	// signal = Limiter.ar(signal);
	ReplaceOut.ar(out, signal);
}).add;

// trying a limiter/depopper/shaper
~dirt.addModule('wall', { |dirtEvent| dirtEvent.sendSynth("dirt_wall" ++ ~dirt.numChannels,
			[wall: ~wall, walllev: ~walllev, out: ~out])}, { ~wall.notNil});
SynthDef("dirt_wall" ++ ~dirt.numChannels, {|out, wall=0, walllev=0.5|
	var signal, mod;
	signal = In.ar(out, ~dirt.numChannels);
	mod = signal - signal.clip2(walllev/2+0.5);
	signal = signal.clip2(walllev/2+0.5) + ((1.0-wall)*mod);
	ReplaceOut.ar(out, signal);
}).add;

// add envelope to lpf
~dirt.addModule('lpf',{ |dirtEvent| dirtEvent.sendSynth("dirt_lpf" ++ ~dirt.numChannels,
			[cutoff: ~cutoff, resonance: ~resonance, out: ~out, fattack:~fattack, fhold:~fhold, frelease:~frelease,
		    fenv:~fenv, flfo:~flfo, flfof:~flfof])}, { ~cutoff.notNil });
SynthDef("dirt_lpf" ++ numChannels, { |out, cutoff = 440, resonance = 0, fattack=0, fhold=1, frelease=0, fenv=0, flfo,flfof,sustain|
	var signal = In.ar(out, numChannels);
	var env = Lag.ar(EnvGen.ar(Env.linen(fattack, fhold, frelease, 1, 0)), 0.01);
	var lfo = flfo * SinOsc.kr(flfof,0) + 1;
	// signal = RLPF.ar(signal, clip(cutoff+(env*fenv),2,20000), resonance.linexp(0, 1, 1, 0.001));
	signal = BLowPass4.ar(signal, clip(lfo*(cutoff + (env*fenv)), 2, 20000), resonance.linexp(0,1,1,0.001));
	ReplaceOut.ar(out, signal)
}, [\ir, \ir, \ir]).add;

// ~dirt.addModule('distort_two', { |dirtEvent| dirtEvent.sendSynth("dirt_distort2" ++ ~dirt.numChannels,
// [distort2: ~distort2, out: ~out])}, { ~distort2.notNil});
// SynthDef("dirt_distort2" ++ ~dirt.numChannels, {|out, distort2=0|
// 	var signal, mod ;
// 	signal = In.ar(out, ~dirt.numChannels);
// 	mod = sin( signal.multiply.fold2(0.5-(distort2/4.0)) * 10 * pi * (distort2/4+1) ) * (1.0-(distort2*distort2/1.4));
// 	mod = SelectX.ar(distort2, [signal, mod]);
// 	ReplaceOut.ar(out, mod);
// }).add;


// this compressor is per-voice, so no memory from one sample to the next, would need a global effect for that
~dirt.addModule('comp', { |dirtEvent|
		dirtEvent.sendSynth("dirt_comp" ++ ~dirt.numChannels,
			[comp: ~comp, compa: ~compa, compr: ~compr, out: ~out])},
{ ~comp.notNil});
SynthDef("dirt_comp" ++ ~dirt.numChannels, {|out, comp=0, compa=0, compr=0|
	var signal, mod, inlev, cgain;
	signal = In.ar(out, ~dirt.numChannels);
	inlev = Amplitude.ar(HPF.ar(signal, 600, 1.5), 0.01+compa, 0.02+compr);
	mod = signal / max( inlev, 0.1) * 0.3;
	mod = SelectX.ar(comp, [signal, mod]);
	ReplaceOut.ar(out, mod);
}).add;

// fm with a sine wave
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

// not actually a saw anymore, just a "chopper"
~dirt.addModule('envsaw', { |dirtEvent|
	dirtEvent.sendSynth('dirt_envsaw' ++ ~dirt.numChannels,
		[envsaw: ~envsaw, envsawf: ~envsawf, envsawd: ~envsawd, out: ~out])}, { ~envsaw.notNil;});
SynthDef("dirt_envsaw" ++ numChannels, { |out, envsaw, envsawf=10, envsawd=0 |
	var signal, mod;
	signal = In.ar(out, numChannels);
	mod = Lag.ar(LFPulse.ar(envsawf, iphase:0, width:envsawd/2+0.5), 0.050) * envsaw + 1.0 - envsaw;
	// mod = ((Saw.ar(envsawf) * (-1)) + 1.0) * 0.5 * envsaw + 1.0 - envsaw;
	ReplaceOut.ar(out, signal * mod);
}).add;

// reverb, tails will be cut off
// this is really rough on the CPU if you stack it up, cut things off!
~dirt.addModule('boom', { |dirtEvent| dirtEvent.sendSynth("dirt_boom" ++ ~dirt.numChannels,
			[boom: ~boom, out: ~out])}, { ~boom.notNil});
SynthDef("dirt_boom" ++ ~dirt.numChannels, {|out, boom=0|
	var signal, wet;
	signal = In.ar(out, ~dirt.numChannels);
	wet = JPverb.ar(signal, 0.1, damp:0.5, size:0.5, earlyDiff:1, modDepth:0.7, modFreq:2, low:1, mid:0.1, high:0.1);
	ReplaceOut.ar(out, SelectX.ar(boom, [signal, wet]));
}).add;

// an alternative to boom, might be less CPU-hungry
~dirt.addModule('gboom', { |dirtEvent| dirtEvent.sendSynth("dirt_gboom" ++ ~dirt.numChannels,
			[gboom: ~gboom, out: ~out])}, { ~gboom.notNil});
SynthDef("dirt_gboom" ++ ~dirt.numChannels, {|out, gboom=0|
	var signal, wet;
	signal = In.ar(out, ~dirt.numChannels);
	//wet = (abs(Amplitude.ar(signal, 0.01, 0.1)) > 0.2) * signal;
	wet = (abs(signal) > 0.2) * signal;
	wet = FreeVerb.ar(signal, 1, 0.1, 1);
	ReplaceOut.ar(out, SelectX.ar(gboom, [signal, wet]));
}).add;

);
