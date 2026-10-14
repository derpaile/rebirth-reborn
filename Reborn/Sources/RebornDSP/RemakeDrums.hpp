#pragma once
// Native drum voice management and sample playback.
// Native drum voice management and sample playback.
#include "RemakeDrumCurves.hpp"
struct RemakeDrum {
    enum Mode {Plain,Filtered,Dual,Pitched};
    struct Voice {
        bool active=false;
        Mode mode=Plain;
        int sample=0,noise=0,hold=0;
        uint32_t phase=0,increment=256;
        float gain=0,decay=1,pole=0,filter=0,noiseGain=0;
        float pairGain=0,pairNoiseGain=0;
    };
    std::array<Voice,12> voices{};
    const std::vector<int16_t> *samples=nullptr;
    int machine=0,noiseCounter=0,kickCounter=0,hatCounter=0;
    int customSample[11];
    uint8_t controls[30]{};
    float output[64]{};
    float pitch808[128]{},pitch909[128]{};
    float decay909[16]{};
    static constexpr int levelIndex808[11]={3,6,9,12,15,18,20,22,23,26,28};
    static constexpr int levelIndex909[11]={3,7,11,14,17,20,21,22,22,25,27};
    void initialize(int kind,const std::vector<int16_t> *library) {
        machine=kind;samples=library;std::fill(std::begin(customSample),std::end(customSample),-1);
        const uint8_t defaults808[30]={1,0,40,100,64,64,100,64,64,100,64,0,100,64,0,100,64,0,100,0,100,0,100,100,0,100,100,100,100,0};
        const uint8_t defaults909[30]={1,0,32,100,64,64,127,100,64,64,64,100,64,127,100,64,127,100,64,127,100,100,100,32,127,100,64,100,64,64};
        std::memcpy(controls,machine==0?defaults808:defaults909,30);
        double root808=std::pow(2.0,1.0/96.0),root909=std::pow(2.0,1.0/144.0);
        for(int i=0;i<128;i++) {
            pitch808[i]=std::trunc(std::pow(root808,i)*(256.0/std::pow(root808,64)));
            pitch909[i]=std::trunc(std::pow(root909,i)*(256.0/std::pow(root909,64)));
        }
        float decay=1;for(int i=15;i>=0;i--){decay909[i]=decay;decay-=float(2.5e-05);}
    }
    void reset() {for(auto &voice:voices)voice.active=false;noiseCounter=kickCounter=hatCounter=0;std::fill(std::begin(output),std::end(output),0);}
    int selected(int lane,int original) const {return customSample[lane]>=0?customSample[lane]:original;}
    
    void start(int slot,int lane,int resource,Mode mode,float gain,float decay=1,int hold=0,float pole=0,uint32_t increment=256,int noise=0,float noiseGain=0) {
        Voice &v=voices[slot];v={true,mode,selected(lane,resource),noise,hold,0,increment,gain,decay,pole,0,noiseGain,0,0};
        if(v.sample<0||v.sample>=46||samples[v.sample].empty()||(mode==Dual&&samples[noise].empty()))v.active=false;
    }
    void trigger(int lane,float velocity,bool accent,bool strong=false,bool repeated=false) {
        float emphasis=1+controls[2]*(accent?(machine==1?2.f:1.f):0.f)*0.03125f;
        if(machine==1)emphasis*=repeated?1.5f:(strong?2.f:.8f);
        int level=controls[machine==0?levelIndex808[lane]:levelIndex909[lane]];
        float scaled=float(level)*float(level)*emphasis*velocity;
        if(machine==0) {
            if(lane==0) {
                voices[kickCounter&1].decay=0.99f;kickCounter++;
                float pole=bassPole808[controls[4]>>4];
                start(kickCounter&1,lane,0,Filtered,scaled*(1.f/127.f)*.005f*(1-pole),bassDecay808[controls[5]>>3],0,pole);
            } else if(lane==1) {
                noiseCounter=(noiseCounter+1)&31;
                start(2,lane,1+((controls[7]*5)>>7),Dual,scaled*(1.f/127.f)*.025f,1,0,0,256,6+((noiseCounter*13+3)&3),std::pow(controls[8]/127.f,2));
            } else if(lane>=2&&lane<=4) {
                int parameter=9+(lane-2)*3;
                const int resource[3]={17,20,15};
                start(3+lane-2,lane,resource[lane-2]+(controls[parameter+2]!=0),Pitched,scaled/(127.f*127.f),1,0,0,uint32_t(pitch808[controls[parameter+1]]));
            } else if(lane==5) {
                start(6,lane,controls[19]?23:12,Plain,scaled*(1.f/127.f)*.005f);
            } else if(lane==6) {
                start(7,lane,controls[21]?13:19,Plain,scaled*(1.f/127.f)*.005f);
            } else if(lane==7) {
                start(8,lane,10,Plain,scaled*(1.f/127.f)*.005f);
            } else if(lane==8) {
                float pole=bassPole808[controls[24]>>4];
                start(11,lane,14,Filtered,scaled*(1.f/127.f)*.005f*(1-pole),bassDecay808[controls[25]>>3],0,pole);
            } else {
                if(lane==10)for(int i=6;i<=10;i++)voices[i].hold=0;
                // Native drum voice management and sample playback.
                int adjusted=lane==9 ? level/2:level*2/3;
                float hatGain=float(adjusted*adjusted)*emphasis*velocity*(1.f/127.f)*.005f;
                start(lane==9?9:10,lane,lane==9?22:11,Plain,hatGain,lane==9?0.998f:1.f,lane==9?controls[27]*4:0);
            }
        } else {
            if(lane==0) {
                voices[kickCounter&1].decay=0.99f;kickCounter++;
                float pole=bassPole909[controls[5]>>4];
                start(kickCounter&1,lane,25+(controls[4]>>5),Filtered,scaled/(127.f*127.f)*(1-pole),decay909[controls[6]>>3],0,pole);
            } else if(lane==1) {
                noiseCounter=(noiseCounter+1)&31;
                start(2,lane,29+((controls[8]*5)>>7),Dual,scaled/(127.f*127.f),0.998f,controls[9]+30,0,256,34+((noiseCounter*7+1)%3),controls[10]*.01f);
            } else if(lane>=2&&lane<=4) {
                int p=11+(lane-2)*3;
                const float multiplier[3]={1.2f,1.1f,1.4f};
                start(3+lane-2,lane,37+(lane-2),Pitched,scaled*6.200012285262346e-05f*multiplier[lane-2],decay909[controls[p+2]>>3],0,0,uint32_t(pitch909[controls[p+1]]));
            } else if(lane==5||lane==6) {
                start(lane==5?6:7,lane,lane==5?40:41,Plain,scaled*6.200012285262346e-05f*(lane==5?1.1f:2.3f));
            } else if(lane==7||lane==8) {
                if(lane==7)voices[9].decay=0.996f;
                float decay=decay909[controls[lane==7?23:24]>>3];if(lane==7)decay=std::pow(decay,6);
                start(lane==7?8:9,lane,lane==7?42:43,Plain,scaled*6.200012285262346e-05f*(lane==7?.8f:1.1f),decay);
            } else {
                int p=lane==9?25:27;
                start(lane==9?10:11,lane,lane==9?44:45,Pitched,scaled*6.200012285262346e-05f*.6f,1,0,0,uint32_t(pitch909[controls[p+1]]));
            }
        }
    }
    void render() {
        std::fill(std::begin(output),std::end(output),0);
        for(auto &v:voices) {
            if(!v.active)continue;
            const auto &sample=samples[v.sample];
            float multiplier=v.hold>0?1.f:v.decay;if(v.hold>0)v.hold--;
            for(int i=0;i<64&&v.active;i++) {
                if(i%2==0){v.pairGain=v.gain;v.pairNoiseGain=v.noiseGain;}
                size_t index=v.phase>>8;
                if(index>=sample.size()){v.active=false;break;}
                float x=sample[index]/32768.f;
                if(v.mode==Pitched) {
                    int a=sample[index],b=index+1<sample.size()?sample[index+1]:0;
                    x=int16_t(a+int16_t((int(v.phase&255)*(b-a))>>8))/32768.f;
                }
                if(v.mode==Dual) {
                    const auto &noise=samples[v.noise];if(index>=noise.size()){v.active=false;break;}
                    x+=noise[index]/32768.f*v.pairNoiseGain;
                }
                float value=x*v.pairGain;
                if(v.mode==Filtered){value+=v.pole*v.filter;v.filter=value;}
                output[i]+=value;
                v.phase+=v.mode==Pitched?v.increment:256;
                if(i%2==1){if(v.mode==Dual)v.noiseGain*=multiplier;else v.gain*=multiplier;}

            }
            // Native drum voice management and sample playback.
            if(v.mode!=Pitched&&v.gain<0.00098304f)v.active=false;
        }
    }
};
