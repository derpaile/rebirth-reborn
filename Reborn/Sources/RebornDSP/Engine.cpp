#include "RebornDSP.h"
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>
#include "RemakeBass.hpp"
static void initializeTables() {}
struct Note {int midi=48;bool enabled=false,accent=false,slide=false;};
struct Hit {bool enabled=false;float velocity=1;bool strong=false,flam=false;};
struct PatternMeta {int length=16;bool shuffled=true;};
struct AutomationEvent {int tick,device,parameter,value;};
struct MIDIEvent {int tick,device,note,velocity,on;};

#include "RemakeDrums.hpp"
#include "RemakeEffects.hpp"
struct Command {int kind,device,a,b,c,d;float value;};
struct RBEngine {
    std::array<Command,131072> commands{}; std::atomic<uint32_t> write{0},read{0};
    std::atomic<int> publishedTick{0},publishedControls[9][32];bool liveActive[2]{};int auditionFrames=0;
    std::atomic<int> publishedStep{-1};std::atomic<float> publishedPeak{0};
    Bass bass[2];Note notes[2][32][16];Hit hits[2][32][11][16];bool drumAccents[2][32][16]{};
    PatternMeta patterns[4][32];int requested[4]{},active[4]{},lastStep[4]={-1,-1,-1,-1};
    bool requestedOn[4]={true,true,true,true},activeOn[4]={true,true,true,true},released[2]={true,true};
    int64_t origin[4]{},lastBar[4]={-1,-1,-1,-1},lastPulse[4]={-1,-1,-1,-1};double gate[2]{};
    std::atomic<int> deviceSteps[4],devicePatterns[4];std::atomic<bool> publishedPlaying{false};std::atomic<uint32_t> outputFaults{0};
    std::array<AutomationEvent,32768> events{};uint32_t eventCount=0,eventIndex=0;
    std::array<MIDIEvent,32768> midiEvents{};uint32_t midiCount=0,midiIndex=0;int midiHeld[2]={-1,-1},midiOrder[2][96]{},midiVelocity[2][96]{},midiSerial=0;bool externalClock=false;
    int baseline[9][32]{};bool songMode=false,looping=false;int loopStart=0,loopEnd=768;
    int flamStep=-1,flamPattern=0;int64_t flamTick=0;bool flamPending=false;
    std::vector<int16_t> samples[46];RemakeDrum drums[2];
    RBEngine(){for(auto &device:publishedControls)for(auto &p:device)p=-1;drums[0].initialize(0,samples);drums[1].initialize(1,samples);for(int d=0;d<4;d++){deviceSteps[d]=-1;devicePatterns[d]=0;}}
    RemakeRack rack;float tempo=120,swing=0;
    bool playing=false;int blockPosition=64;double patternClock=0;
    float blockL[64]{},blockR[64]{};
    bool push(Command c) {auto w=write.load(std::memory_order_relaxed);auto r=read.load(std::memory_order_acquire);if(w-r>=commands.size())return false;commands[w%commands.size()]=c;write.store(w+1,std::memory_order_release);return true;}
    void drain() {
        auto r=read.load(std::memory_order_relaxed),w=write.load(std::memory_order_acquire);
        while(r!=w){auto c=commands[r++%commands.size()];
            if(c.kind==1){
                if(c.device<2&&c.a>=2&&c.a<=8) bass[c.device].controls[c.a]=std::clamp((int)c.value,0,c.a==8?1:127);
                if(c.device<4&&c.a==20)rack.levels[c.device]=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));
                if(c.device<4&&c.a==21)rack.pans[c.device]=uint8_t(std::lround((std::clamp(c.value,-1.f,1.f)+1)*63.5f));
                if(c.device==4)switch(c.a){
                    case 0:playing=c.value!=0;publishedPlaying=playing;if(!playing){liveActive[0]=liveActive[1]=false;auditionFrames=0;publishedStep=-1;for(auto &b:bass)b.reset(true);for(auto &machine:drums)machine.reset();rack.reset();patternClock=0;eventIndex=0;flamPending=false;for(int d=0;d<4;d++){deviceSteps[d]=-1;lastStep[d]=-1;lastPulse[d]=-1;lastBar[d]=-1;origin[d]=0;}released[0]=released[1]=true;}else if(songMode)seek(int(patternClock));break;
                    case 1:tempo=std::clamp(c.value,30.f,300.f);break;
                    case 2:rack.master=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));break;
                    // Compatibility with the early preview API. The app now sends
                    // original effect parameters through dedicated rack commands.
                    case 3:rack.distortion.controls[1]=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));for(auto &d:rack.distorted)d=c.value>0;break;
                    case 4:for(auto &send:rack.sends)send=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));break;
                    case 5:rack.delay.controls[3]=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));break;
                    case 6:rack.compressor.controls[1]=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));rack.compressorTarget=c.value>0?1:0;break;
                    case 7:rack.pcf.controls[3]=uint8_t(std::lround(std::clamp(c.value,0.f,1.f)*127));rack.pcfTarget=c.value>0?1:0;break;
                }
            }else if(c.kind==2)notes[c.device][0][c.a]={c.b,c.c!=0,(c.d&1)!=0,(c.d&2)!=0};
            else if(c.kind==3)hits[c.device][0][c.a][c.b]={c.c!=0,c.value,c.d!=0};
            else if(c.kind==4)drums[c.device].customSample[c.a]=c.b;
            else if(c.kind==5){drums[c.device].controls[c.a]=uint8_t(c.b);if(c.a==0)requestedOn[c.device+2]=c.b!=0;if(c.a==1)requested[c.device+2]=std::clamp(c.b,0,31);}
            else if(c.kind==6)drumAccents[c.device][0][c.a]=c.b!=0;
            else if(c.kind==7){
                uint8_t *controls=c.device==0?rack.distortion.controls:c.device==1?rack.delay.controls:c.device==2?rack.compressor.controls:rack.pcf.controls;
                controls[c.a]=uint8_t(c.b);
            }else if(c.kind==8){rack.sends[c.device]=uint8_t(c.a);rack.distorted[c.device]=c.b!=0;}
            else if(c.kind==9){rack.pcfTarget=uint8_t(c.a);rack.compressorTarget=uint8_t(c.b);}
            else if(c.kind==10)patterns[c.device][c.a]={c.b,c.c!=0};
            else if(c.kind==11){requested[c.device]=c.a;requestedOn[c.device]=c.b!=0;}
            else if(c.kind==12)notes[c.device][c.a][c.b]={c.c,(c.d&1)!=0,(c.d&2)!=0,(c.d&4)!=0};
            else if(c.kind==13){int strength=int(c.value);hits[c.device][c.a][c.b][c.c]={strength!=0,1,strength==2||strength==4,strength>2};}
            else if(c.kind==14)drumAccents[c.device][c.a][c.b]=c.c!=0;
            else if(c.kind==15)rack.audible[c.device]=c.a!=0;
            else if(c.kind==16){eventCount=eventIndex=0;}
            else if(c.kind==17&&eventCount<events.size())events[eventCount++]={c.a,c.device,c.b,c.c};
            else if(c.kind==30){midiCount=midiIndex=0;}
            else if(c.kind==31&&midiCount<midiEvents.size()){midiEvents[midiCount++]={c.a,c.device,c.b,c.c,c.d};}
            else if(c.kind==32){externalClock=c.a!=0;}
            else if(c.kind==33){if(externalClock&&playing)patternClock+=8;}
            else if(c.kind==25){baseline[c.device][c.a]=c.b;}
            else if(c.kind==26){liveActive[0]=liveActive[1]=false;auditionFrames=0;for(auto &b:bass)b.reset(true);for(auto &d:drums)d.reset();rack.reset();seek(c.a);}
            else if(c.kind==22){liveActive[0]=liveActive[1]=false;for(auto &b:bass){b.highQuality=c.a!=0;b.reset(true);}lastPulse[0]=lastPulse[1]=-1;}
            else if(c.kind==21){automate(c.device,c.a,c.b);}
            else if(c.kind==19){if(c.c){bass[c.device].outgoingSlide=liveActive[c.device]&&c.d!=0;liveActive[c.device]=true;bass[c.device].note(c.a,c.b!=0,c.d!=0);}else{liveActive[c.device]=false;bass[c.device].rest();}auditionFrames=44100*4;}
            else if(c.kind==20){drums[c.device].trigger(c.a,c.value,c.b!=0,c.c!=0);auditionFrames=44100*4;}
            else if(c.kind==18){songMode=c.device!=0;loopStart=c.a;loopEnd=c.b;looping=c.c!=0;for(int d=0;d<9;d++)for(int p=0;p<32;p++)baseline[d][p]=controller(d,p);}
        }read.store(r,std::memory_order_release);
    }
    int controller(int d,int p) {
        if(d==0){if(p==1)return rack.compressorTarget;if(p==2)return rack.pcfTarget;if(p>=5&&p<29){int channel=(p-5)/6;switch((p-5)%6){case 1:return rack.levels[channel];case 2:return rack.pans[channel];case 3:return rack.sends[channel];case 4:return rack.distorted[channel];}}}
        if(d==1||d==2){if(p==0)return requestedOn[d-1];if(p==1)return requested[d-1];if(p>=2&&p<=8)return bass[d-1].controls[p];}
        if(d==3||d==4){if(p==0)return requestedOn[d-1];if(p==1)return requested[d-1];if(p>=2&&p<(d==3?29:30))return drums[d-3].controls[p];}
        if(d>=5&&d<=8){int effect=d==5?1:d==6?0:d==7?3:2;int count=effect==1?5:effect==3?7:3;uint8_t *c=effect==0?rack.distortion.controls:effect==1?rack.delay.controls:effect==2?rack.compressor.controls:rack.pcf.controls;if(p<count)return c[p];}
        return -1;
    }
    void automate(int d,int p,int value) {
        if(d==0){if(p==1)rack.compressorTarget=std::clamp(value,0,5);else if(p==2)rack.pcfTarget=std::clamp(value,0,4);else if(p>=5&&p<29){int channel=(p-5)/6;switch((p-5)%6){case 1:rack.levels[channel]=value;break;case 2:rack.pans[channel]=value;break;case 3:rack.sends[channel]=value;break;case 4:rack.distorted[channel]=value!=0;break;}}}
        else if(d>=1&&d<=4){int device=d-1;if(p==0)requestedOn[device]=value!=0;else if(p==1)requested[device]=std::clamp(value,0,31);else if(device<2&&p<=8)bass[device].controls[p]=value;else if(device>=2&&p<(device==2?29:30))drums[device-2].controls[p]=value;}
        else if(d>=5&&d<=8){int effect=d==5?1:d==6?0:d==7?3:2;int count=effect==1?5:effect==3?7:3;uint8_t *c=effect==0?rack.distortion.controls:effect==1?rack.delay.controls:effect==2?rack.compressor.controls:rack.pcf.controls;if(p<count)c[p]=uint8_t(effect==3&&p==4?std::min(value,54):value);}
    }
    void rememberMIDI(const MIDIEvent &event){
        int d=event.device,n=event.note;if(event.on){midiOrder[d][n]=++midiSerial;midiVelocity[d][n]=event.velocity;}else midiOrder[d][n]=0;
    }
    int latestMIDI(int device)const{
        int latest=-1;for(int note=0;note<96;note++)if(midiOrder[device][note] && (latest<0 || midiOrder[device][note]>midiOrder[device][latest]))latest=note;return latest;
    }
    void playMIDI(const MIDIEvent &event){
        if(event.device<2){int d=event.device,previous=midiHeld[d];rememberMIDI(event);int note=latestMIDI(d);
            if(event.on || note!=previous){if(note>=0){bool slide=liveActive[d];bass[d].outgoingSlide=slide;liveActive[d]=true;midiHeld[d]=note;bass[d].note(note,midiVelocity[d][note]>=96,slide);}else{liveActive[d]=false;midiHeld[d]=-1;bass[d].rest();}}
        }else if(event.on)drums[event.device-2].trigger(event.note,float(event.velocity)/127,false,event.velocity>=96);
    }
    void seek(int tick) {
        for(int d=0;d<9;d++)for(int p=0;p<32;p++)if(baseline[d][p]>=0)automate(d,p,baseline[d][p]);
        midiIndex=0;midiHeld[0]=midiHeld[1]=-1;liveActive[0]=liveActive[1]=false;midiSerial=0;
        for(auto &keys:midiOrder)std::fill(std::begin(keys),std::end(keys),0);
        while(midiIndex<midiCount&&midiEvents[midiIndex].tick<tick){const auto &event=midiEvents[midiIndex++];if(event.device<2)rememberMIDI(event);}
        for(int d=0;d<2;d++){int note=latestMIDI(d);if(note>=0){midiHeld[d]=note;liveActive[d]=true;bass[d].note(note,midiVelocity[d][note]>=96,false);}}
        eventIndex=0;while(eventIndex<eventCount&&events[eventIndex].tick<=tick){auto &event=events[eventIndex++];automate(event.device,event.parameter,event.value);}
        for(int d=0;d<4;d++){lastStep[d]=-1;lastPulse[d]=-1;lastBar[d]=-1;origin[d]=(tick/768)*768;}
        flamPending=false;patternClock=tick;
    }
    void generate() {
        drain();
        int64_t raw=int64_t(patternClock);
        if(playing&&songMode){if(looping&&raw>=loopEnd){seek(loopStart+int(raw-loopEnd));raw=int64_t(patternClock);}while(eventIndex<eventCount&&events[eventIndex].tick<=raw){auto &event=events[eventIndex++];automate(event.device,event.parameter,event.value);}}
        if(playing&&songMode){while(midiIndex<midiCount&&midiEvents[midiIndex].tick<=raw)playMIDI(midiEvents[midiIndex++]);}
        if(playing){
            int64_t bar=raw/768;
            // Shuffle shifts the second pulse within each step pair.
            int delay=int(std::clamp(swing*288.f,0.f,127.f))/6;
            int64_t shuffled=(raw/96)*96+std::max(int(raw%96)-delay,0);
            publishedStep=int(raw/48)%16;
            for(int d=0;d<4;d++) {
                if(lastBar[d]!=bar){if(lastBar[d]<0||requested[d]!=active[d]){active[d]=requested[d];origin[d]=bar*768;lastStep[d]=-1;lastPulse[d]=-1;}activeOn[d]=requestedOn[d];lastBar[d]=bar;devicePatterns[d]=active[d];}
                auto meta=patterns[d][active[d]];int64_t ticks=meta.shuffled?shuffled:raw;
                int64_t pulse=(ticks-origin[d])/48;int current=int(pulse%meta.length);
                deviceSteps[d]=activeOn[d]?current:-1;
                if(pulse!=lastPulse[d]) {
                    lastPulse[d]=pulse;lastStep[d]=current;
                    if(d<2&&!liveActive[d]){auto n=notes[d][active[d]][current];if(activeOn[d])bass[d].note(n.midi,n.accent,n.slide,!n.enabled);else bass[d].rest();gate[d]=(ticks-origin[d])/48*48+origin[d]+24;released[d]=false;}
                    else if(d>=2){
                        int machine=d-2;for(int order=0;order<11;order++){int lane=machine==0?order:10-order;auto hit=hits[machine][active[d]][lane][current];if(activeOn[d]&&hit.enabled)drums[machine].trigger(lane,hit.velocity,drumAccents[machine][active[d]][current],hit.strong);}
                        if(machine==1){flamStep=current;flamPattern=active[d];flamPending=activeOn[d];flamTick=raw+1+int64_t(drums[1].controls[29])*int64_t(std::lround(tempo*1000))/700000;}
                    }
                }
                if(d<2&&!liveActive[d]&&!released[d]&&ticks>=gate[d]){bass[d].release();released[d]=true;}
            }
            if(flamPending&&raw>flamTick){flamPending=false;for(int lane=10;lane>=0;lane--){auto hit=hits[1][flamPattern][lane][flamStep];if(hit.enabled&&hit.flam)drums[1].trigger(lane,hit.velocity,drumAccents[1][flamPattern][flamStep],false,true);}}
        }
        if(playing||liveActive[0]||liveActive[1]||auditionFrames>0){
            for(auto &b:bass)b.render();for(auto &d:drums)d.render();
            float *channels[4]={bass[0].output,bass[1].output,drums[0].output,drums[1].output};
            rack.process(channels,blockL,blockR,tempo,raw);
        }else {std::fill(std::begin(blockL),std::end(blockL),0);std::fill(std::begin(blockR),std::end(blockR),0);}
        float peak=0;
        for(int i=0;i<64;i++) {
            if(!std::isfinite(blockL[i])||!std::isfinite(blockR[i])){outputFaults++;blockL[i]=blockR[i]=0;for(auto &b:bass)b.reset(true);rack.reset();}
            blockL[i]=std::clamp(blockL[i],-1.f,1.f);blockR[i]=std::clamp(blockR[i],-1.f,1.f);
            peak=std::max(peak,std::max(std::abs(blockL[i]),std::abs(blockR[i])));
        }
        if(auditionFrames>0)auditionFrames=std::max(0,auditionFrames-64);
        publishedTick=int(std::min(patternClock,100000000.0));
        for(int d=0;d<9;d++)for(int p=0;p<32;p++)publishedControls[d][p].store(controller(d,p),std::memory_order_relaxed);
        publishedPeak=peak;if(playing&&!externalClock)patternClock+=64*double(tempo)*192/(44100*60);blockPosition=0;
    }
};
extern "C" RBEngine *rb_create(){initializeTables();(void)remakeEffectTables();return new RBEngine;}
extern "C" void rb_destroy(RBEngine *e){delete e;}
extern "C" int rb_parameter(RBEngine *e,int d,int p,float v){if(!e||d<0||d>4||p<0||!std::isfinite(v))return 0;return e->push({1,d,p,0,0,0,v});}
extern "C" int rb_note_step(RBEngine *e,int d,int s,int n,int en,int ac,int sl){if(!e||d<0||d>1||s<0||s>15||n<0||n>95)return 0;return e->push({2,d,s,n,en,(ac?1:0)|(sl?2:0),0});}
extern "C" int rb_drum_step(RBEngine *e,int d,int lane,int s,int en,float v){if(!e||d<0||d>1||lane<0||lane>10||s<0||s>15||!std::isfinite(v))return 0;return e->push({3,d,lane,s,en,0,std::clamp(v,0.f,1.f)});}
extern "C" int rb_drum_step_strength(RBEngine *e,int d,int lane,int s,int en,float v,int strong){if(!e||d<0||d>1||lane<0||lane>10||s<0||s>15||!std::isfinite(v))return 0;return e->push({3,d,lane,s,en,strong,std::clamp(v,0.f,1.f)});}
extern "C" int rb_sample(RBEngine *e,int d,int lane,int sample){if(!e||d<0||d>1||lane<0||lane>10||sample< -1||sample>45)return 0;return e->push({4,d,lane,sample,0,0,0});}
extern "C" int rb_drum_parameter(RBEngine *e,int d,int p,int value){if(!e||d<0||d>1||p<0||p>(d==0?28:29)||value<0||value>127)return 0;return e->push({5,d,p,value,0,0,0});}
extern "C" int rb_drum_accent(RBEngine *e,int d,int step,int accent){if(!e||d<0||d>1||step<0||step>15)return 0;return e->push({6,d,step,accent,0,0,0});}
extern "C" int rb_effect_parameter(RBEngine *e,int effect,int parameter,int value){
    if(!e||effect<0||effect>3||value<0||value>127)return 0;
    int count=effect==1?5:effect==3?7:3;
    if(parameter<0||parameter>=count|| (parameter==0&&value>1) || (effect==1&&parameter==2&&value>1) || (effect==3&&parameter==4&&value>54) || (effect==3&&parameter==6&&value>1))return 0;
    return e->push({7,effect,parameter,value,0,0,0});
}
extern "C" int rb_channel_effects(RBEngine *e,int device,int send,int distortion){if(!e||device<0||device>3||send<0||send>127||distortion<0||distortion>1)return 0;return e->push({8,device,send,distortion,0,0,0});}
extern "C" int rb_effect_routes(RBEngine *e,int pcf,int compressor){if(!e||pcf<0||pcf>4||compressor<0||compressor>5)return 0;return e->push({9,0,pcf,compressor,0,0,0});}
extern "C" int rb_pattern_meta(RBEngine *e,int device,int pattern,int length,int shuffled){if(!e||device<0||device>3||pattern<0||pattern>31||length<1||length>16||shuffled<0||shuffled>1)return 0;return e->push({10,device,pattern,length,shuffled,0,0});}
extern "C" int rb_pattern_select(RBEngine *e,int device,int pattern,int enabled){if(!e||device<0||device>3||pattern<0||pattern>31||enabled<0||enabled>1)return 0;return e->push({11,device,pattern,enabled,0,0,0});}
extern "C" int rb_note_pattern_step(RBEngine *e,int device,int pattern,int step,int midi,int enabled,int accent,int slide){if(!e||device<0||device>1||pattern<0||pattern>31||step<0||step>15||midi<0||midi>95)return 0;return e->push({12,device,pattern,step,midi,(enabled?1:0)|(accent?2:0)|(slide?4:0),0});}
extern "C" int rb_drum_pattern_step(RBEngine *e,int device,int pattern,int lane,int step,int strength){if(!e||device<0||device>1||pattern<0||pattern>31||lane<0||lane>10||step<0||step>15||strength<0||strength>4)return 0;return e->push({13,device,pattern,lane,step,0,float(strength)});}
extern "C" int rb_drum_pattern_accent(RBEngine *e,int device,int pattern,int step,int accent){if(!e||device<0||device>1||pattern<0||pattern>31||step<0||step>15||accent<0||accent>1)return 0;return e->push({14,device,pattern,step,accent,0,0});}
extern "C" int rb_channel_enabled(RBEngine *e,int device,int enabled){if(!e||device<0||device>3||enabled<0||enabled>1)return 0;return e->push({15,device,enabled,0,0,0,0});}
extern "C" int rb_song_clear(RBEngine *e){return e?e->push({16,0,0,0,0,0,0}):0;}
extern "C" int rb_song_event(RBEngine *e,int tick,int device,int parameter,int value){if(!e||tick<0||tick>100000000||device<0||device>8||parameter<0||parameter>127||value<0||value>127)return 0;return e->push({17,device,tick,parameter,value,0,0});}
extern "C" int rb_song_mode(RBEngine *e,int enabled,int start,int end,int looping){if(!e||enabled<0||enabled>1||start<0||end<=start||end>100000001||looping<0||looping>1)return 0;return e->push({18,enabled,start,end,looping,0,0});}
extern "C" int rb_current_device_step(RBEngine *e,int device){return e&&device>=0&&device<4?e->deviceSteps[device].load():-1;}
extern "C" int rb_current_pattern(RBEngine *e,int device){return e&&device>=0&&device<4?e->devicePatterns[device].load():-1;}
extern "C" uint32_t rb_faults(RBEngine *e){return e?e->outputFaults.load():0;}
extern "C" int rb_is_playing(RBEngine *e){return e&&e->publishedPlaying.load();}
static uint32_t be32(const unsigned char *p){return (uint32_t(p[0])<<24)|(uint32_t(p[1])<<16)|(uint32_t(p[2])<<8)|p[3];}
static bool decodeAiff(const unsigned char *b,size_t size,std::vector<int16_t> &sample){
    if(!b||size<12||memcmp(b,"FORM",4)||memcmp(b+8,"AIFF",4)||be32(b+4)!=size-8)return false;
    bool supported=false;size_t dataOffset=0,dataSize=0;uint32_t frames=0;
    for(size_t at=12;at<size;){if(at+8>size)return false;uint32_t n=be32(b+at+4);if(n>size-at-8||n+(n&1)>size-at-8)return false;
        // Shipped Mods also use a 12-byte COMM with the four significant 44100-Hz bytes.
        if(!memcmp(b+at,"COMM",4)&&n>=12){auto p=b+at+8;frames=be32(p+2);supported=p[0]==0&&p[1]==1&&p[6]==0&&p[7]==16&&p[8]==0x40&&p[9]==0x0e&&p[10]==0xac&&p[11]==0x44;}
        if(!memcmp(b+at,"SSND",4)&&n>=8){auto skip=be32(b+at+8);if(skip>n-8)return false;dataOffset=at+16+skip;dataSize=n-8-skip;}
        at+=8+n+(n&1);
    }
    if(!supported||!dataOffset||dataSize%2||dataSize/2!=frames||!frames)return false;
    sample.resize(frames);for(size_t i=0;i<frames;i++){auto p=b+dataOffset+i*2;sample[i]=int16_t((uint16_t(p[0])<<8)|p[1]);}return true;
}
struct RBSampleBank{std::array<std::vector<int16_t>,46> samples;std::array<bool,46> loaded{};};
extern "C" RBSampleBank *rb_sample_bank_create(){return new RBSampleBank;}
extern "C" void rb_sample_bank_destroy(RBSampleBank *b){delete b;}
extern "C" int rb_sample_bank_aiff(RBSampleBank *b,int id,const uint8_t *bytes,uint32_t length){if(!b||id<0||id>=46)return 0;std::vector<int16_t> s;if(!decodeAiff(bytes,length,s))return 0;b->samples[id]=std::move(s);b->loaded[id]=true;return 1;}
extern "C" int rb_sample_bank_commit(RBEngine *e,RBSampleBank *b){if(!e||!b||e->playing||!std::all_of(b->loaded.begin(),b->loaded.end(),[](bool v){return v;}))return 0;for(auto &drum:e->drums)drum.reset();for(int i=0;i<46;i++)e->samples[i]=std::move(b->samples[i]);b->loaded.fill(false);return 1;}
extern "C" int rb_load_aiff(RBEngine *e,int id,const char *path){
    if(!e||id<0||id>=46||!path)return 0;std::ifstream f(path,std::ios::binary);if(!f)return 0;
    std::vector<unsigned char>b((std::istreambuf_iterator<char>(f)),{});std::vector<int16_t> s;if(!decodeAiff(b.data(),b.size(),s))return 0;e->samples[id]=std::move(s);return 1;
}
extern "C" void rb_render(RBEngine *e,float *l,float *r,uint32_t frames){if(!e||!l||!r)return;for(uint32_t i=0;i<frames;i++){if(e->blockPosition==64)e->generate();l[i]=e->blockL[e->blockPosition];r[i]=e->blockR[e->blockPosition++];}}
extern "C" int rb_song_baseline(RBEngine *e,int d,int p,int v){if(!e||d<0||d>8||p<0||p>=32||v<0||v>127)return 0;return e->push({25,d,p,v,0,0,0});}
extern "C" int rb_seek(RBEngine *e,int tick){if(!e||tick<0||tick>100000000)return 0;return e->push({26,0,tick,0,0,0,0});}
extern "C" int rb_tick(RBEngine *e){return e?e->publishedTick.load():0;}
extern "C" int rb_controller(RBEngine *e,int d,int p){return e&&d>=0&&d<9&&p>=0&&p<32?e->publishedControls[d][p].load(std::memory_order_relaxed):-1;}
extern "C" int rb_set_controller(RBEngine *e,int d,int p,int v){if(!e||d<0||d>8||p<0||p>=32||v<0||v>127)return 0;bool valid=d==0?(p==1||p==2||(p>=5&&p<29&&(p-5)%6>=1&&(p-5)%6<=4)):d<3?p<=8:d<5?p<(d==3?29:30):p<(d==5?5:d==7?7:3);return valid?e->push({21,d,p,v,0,0,0}):0;}
extern "C" int rb_quality(RBEngine *e,int high){return e&&high>=0&&high<=1?e->push({22,0,high,0,0,0,0}):0;}
extern "C" int rb_live_note(RBEngine *e,int d,int n,int on,int accent,int slide){if(!e||d<0||d>1||n<0||n>95||on<0||on>1)return 0;return e->push({19,d,n,accent,on,slide,0});}
extern "C" int rb_live_drum(RBEngine *e,int d,int lane,float velocity,int accent,int strong){if(!e||d<0||d>1||lane<0||lane>10||!std::isfinite(velocity))return 0;return e->push({20,d,lane,accent,strong,0,std::clamp(velocity,0.f,1.f)});}
extern "C" int rb_current_step(RBEngine *e){return e?e->publishedStep.load():-1;}
extern "C" float rb_peak(RBEngine *e){return e?e->publishedPeak.load():0;}

extern "C" int rb_midi_sync(RBEngine *e,int enabled){return e&&enabled>=0&&enabled<=1?e->push({32,0,enabled,0,0,0,0}):0;}
extern "C" int rb_midi_clock(RBEngine *e){return e?e->push({33,0,0,0,0,0,0}):0;}
extern "C" int rb_song_notes_clear(RBEngine *e){return e?e->push({30,0,0,0,0,0,0}):0;}
extern "C" int rb_song_note_event(RBEngine *e,int tick,int d,int note,int velocity,int on){if(!e||tick<0||tick>100000001||d<0||d>3||note<0||note>(d<2?95:10)||velocity<1||velocity>127||on<0||on>1)return 0;return e->push({31,d,tick,note,velocity,on,0});}
