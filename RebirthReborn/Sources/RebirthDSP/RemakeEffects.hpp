#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iterator>
#include <cstring>
#include "RemakePatterns.hpp"

// Procedural remake DSP; no extracted lookup data.
// Procedural remake DSP; no extracted lookup data.
struct RemakeEffectTables {
    float gain[128]{}, curves[32][256]{};
    struct Filter {float a,b,c;};
    Filter low[8][512]{}, high[8][512]{};
    float smoothA=0,smoothB=0,smoothC=0;
    RemakeEffectTables() {
        gain[127]=1;for(int i=126;i>0;i--)gain[i]=gain[i+1]*(23.f/24.f);
        for(int shape=0;shape<32;shape++)for(int i=0;i<256;i++){
            const double drive=1.0+shape*0.18,x=(i-128)/128.0;
            curves[shape][i]=float(std::tanh(x*drive)/std::tanh(drive));
        }
        for(int q=0;q<8;q++)for(int i=0;i<512;i++){
            const double frequency=40*std::pow(18000.0/40,i/511.0)/44100;
            const double quality=0.6+q*0.35,radius=std::exp(-3.141592653589793*frequency/quality);
            const double a=2*radius*std::cos(6.283185307179586*frequency),b=radius*radius;
            low[q][i]={float(a),float(b),float((1-a+b)*0.9/(1+q*0.06))};
            high[q][i]={float(a),float(b),float(std::sqrt(std::max(1e-12,1-a+b))*0.7/(1+q*0.06))};
        }
        smoothA=1.86f;smoothB=0.865f;smoothC=1-smoothA+smoothB;
    }
    void pan(int level,int position,float &left,float &right)const {
        int offset=position-64,attenuation=offset*offset/32;
        left=gain[std::clamp(level-(offset>0?attenuation:0),0,127)];
        right=gain[std::clamp(level-(offset<0?attenuation:0),0,127)];
    }
};
inline const RemakeEffectTables &remakeEffectTables() {static const RemakeEffectTables table;return table;}

struct RemakeDistortion {
    uint8_t controls[3]={1,70,0};
    uint32_t counter=0;float drive=0,outputGain=0,targetDrive=0,targetGain=0;
    void reset(){counter=0;drive=outputGain=targetDrive=targetGain=0;}
    void update() {
        auto &t=remakeEffectTables();
        float shape=float(controls[2])*float(1.0/127)*float(3.999);
        float amount=float(controls[1])*float(1.0/127)*float(3.999);
        int x=int(shape),y=int(amount);float fx=shape-x,fy=amount-y;
        float a=distortionGain(x,y)+(distortionGain(x,y+1)-distortionGain(x,y))*fy;
        float b=distortionGain(x+1,y)+(distortionGain(x+1,y+1)-distortionGain(x+1,y))*fy;
        targetGain=(a+(b-a)*fx)*5*.00390625f;
        targetDrive=(t.gain[controls[1]]+.0625f)*2048;
    }
    void process(float *buffer) {
        if(!controls[0])return;
        if((counter++&15)==0)update();
        auto &t=remakeEffectTables();
        drive=.9f*drive+.1f*targetDrive;outputGain=.9f*outputGain+.1f*targetGain;
        if(controls[2]==0) {
            float multiplier=16*t.gain[controls[1]]+1;
            float limit=1/(16*t.gain[std::min(int(controls[1]),90)]+1);
            for(int i=0;i<64;i++)buffer[i]=std::clamp(buffer[i]*multiplier,-limit,limit);
        }else {
            auto curve=t.curves[(controls[2]*32)>>7];
            for(int i=0;i<64;i++) {
                float position=buffer[i]*drive+128,value;
                if(position<0)value=curve[0];
                else if(position>254)value=curve[254];
                else {int index=int(position);value=curve[index]+(curve[index+1]-curve[index])*(position-index);}
                buffer[i]=value*outputGain;
            }
        }
    }
};

struct RemakeCompressor {
    uint8_t controls[3]={1,70,64};
    uint32_t counter=0;int hold=0;float envelope=1,gain=0,scale=1,offset=1,minimum=1000;
    void reset(){counter=0;hold=0;envelope=1;gain=0;scale=offset=1;minimum=1000;}
    void update() {
        float ratio=controls[1]*float(1.0/127);
        offset=1-ratio*.99f;
        scale=(controls[2]*.03125f+1)*ratio*.3662109375f;
        minimum=(controls[2]*float(1.0/127)*80000)*(1.f/32768)+.01220703125f;
    }
    // Procedural remake DSP; no extracted lookup data.
    // absolute sum of samples 1 and 3 in each quartet, not their peak magnitude.
    void process(float *left,float *right=nullptr) {
        if(!controls[0])return;
        if((counter++&15)==0)update();
        for(int i=0;i<64;i+=4) {
            float detector=left[i+1]+left[i+3];
            if(right)detector+=right[i+1]+right[i+3];
            detector=std::abs(detector);
            if(envelope<detector){envelope+=(detector-envelope)*.01f;hold=300;}
            else if(hold)hold--;
            else envelope=envelope*0.9984f+1e-6f;
            envelope=std::max(envelope,minimum);
            float increment=(scale/envelope+offset-gain)*.25f;
            for(int j=0;j<4;j++){gain+=increment;left[i+j]*=gain;if(right)right[i+j]*=gain;}
        }
    }
};

struct RemakeDelay {
    uint8_t controls[5]={1,3,1,80,64};
    float ring[131072]{};uint32_t head=0,counter=0,length=0;
    float targetL=0,targetR=0,returnL=0,returnR=0,feedback=0;bool cleared=false;
    RemakeDelay(){reset();}
    void reset(){std::fill(std::begin(ring),std::end(ring),1e-6f);head=counter=length=0;targetL=targetR=returnL=returnR=feedback=0;cleared=true;}
    void update(float tempo) {
        uint32_t scaledTempo=uint32_t(std::lround(tempo*1000));
        uint32_t denominator=scaledTempo*(controls[2]?4:3)/100;
        length=std::min(uint32_t(uint64_t(controls[1])*26460000/denominator),131071u);
        remakeEffectTables().pan(127,controls[4],targetL,targetR);
        targetL+=1e-6f;targetR+=1e-6f;feedback=controls[3]*float(1.0/127);
    }
    // Procedural remake DSP; no extracted lookup data.
    void process(float *send,float *left,float *right,float tempo) {
        if(!controls[0]) {
            if(!cleared){std::fill(std::begin(ring),std::end(ring),1e-6f);cleared=true;}
            std::fill(send,send+64,1e-6f);return;
        }
        cleared=false;if((counter++&15)==0)update(tempo);
        returnL=.9f*returnL+.1f*targetL;returnR=.9f*returnR+.1f*targetR;
        for(int i=0;i<64;i++) {
            float tap=ring[(head-length)&131071];
            left[i]+=tap*returnL;right[i]+=tap*returnR;
            ring[head]=tap*feedback+send[i];send[i]=1e-6f;head=(head+1)&131071;
        }
    }
};

struct RemakePCF {
    uint8_t controls[7]={1,70,64,40,24,90,1};
    float cutoff1=0,cutoff2=0,envelope=0,position=0,alpha=0,decay=0;
    float low1=0,low2=0,high1=0,high2=0;int previousStep=-1;
    void reset(){cutoff1=cutoff2=envelope=position=alpha=decay=low1=low2=high1=high2=0;previousStep=-1;}
    // Procedural remake DSP; no extracted lookup data.
    void process(float *buffer,int64_t ticks) {
        if(!controls[0])return;
        auto &t=remakeEffectTables();int pattern=controls[4],q=(controls[2]*8)>>7;
        int step=int((ticks/(768/pcfDivisions[pattern]))%pcfLengths[pattern]);
        float cutoff=float(double(controls[1])*4*t.smoothC+double(t.smoothA)*cutoff1-double(t.smoothB)*cutoff2);
        cutoff2=cutoff1;cutoff1=cutoff;
        double env=envelope,pos=position;
        if(step!=previousStep) {
            previousStep=step;decay=pcfDecay[controls[5]>>3];
            int event=pcfEvents[pattern][step];
            if(event) {
                env=(event*controls[3])>>5;
                if(env+cutoff>511)env=511-double(cutoff);
                alpha=(event&1)?0.995f:0;
            }
        }
        // Procedural remake DSP; no extracted lookup data.
        // while outputs and state crossing a block boundary are float32.
        double one=controls[6]==1?low1:high1,two=controls[6]==1?low2:high2;
        for(int i=0;i<64;i+=4) {
            env*=decay;
            pos=(env+cutoff)*(1-double(alpha))+pos*alpha;
            int index=int(std::clamp(pos,0.0,511.0));
            auto c=controls[6]==1?t.low[q][index]:t.high[q][index];
            for(int j=0;j<4;j++) {
                double next=c.a*one+double(buffer[i+j])*c.c-c.b*two;
                buffer[i+j]=float(controls[6]==1?next:next-one);
                two=one;one=next;
            }
        }
        envelope=float(env);position=float(pos);
        if(controls[6]==1){low1=float(one);low2=float(two);high1=high2=0;}
        else{high1=float(one);high2=float(two);low1=low2=0;}
    }
};

struct RemakeRack {
    RemakeDistortion distortion;RemakeDelay delay;RemakeCompressor compressor;RemakePCF pcf;
    uint8_t levels[4]={100,100,100,100},pans[4]={64,64,64,64},sends[4]{};
    bool distorted[4]{},audible[4]={true,true,true,true};uint8_t pcfTarget=0,compressorTarget=0,master=100;
    float smoothL[4]{},smoothR[4]{},targetL[4]{},targetR[4]{},sendGain[4]{};
    float masterSmooth=0,masterTarget=0;uint32_t counter=0;
    void reset() {
        distortion.reset();delay.reset();compressor.reset();pcf.reset();counter=0;masterSmooth=masterTarget=0;
        std::fill(std::begin(smoothL),std::end(smoothL),0);std::fill(std::begin(smoothR),std::end(smoothR),0);
    }
    void targets() {
        auto &t=remakeEffectTables();
        for(int d=0;d<4;d++){int level=audible[d]?levels[d]:0;t.pan(level,pans[d],targetL[d],targetR[d]);targetL[d]+=1e-6f;targetR[d]+=1e-6f;sendGain[d]=t.gain[level]*t.gain[sends[d]]+1e-6f;}
        masterTarget=2*t.gain[master]+1e-6f;
    }
    void process(float *channels[4],float *left,float *right,float tempo,int64_t ticks) {
        if((counter++&15)==0)targets();
        float send[64];std::fill(send,send+64,1e-6f);std::fill(left,left+64,1e-6f);std::fill(right,right+64,1e-6f);
        // Procedural remake DSP; no extracted lookup data.
        // The distortion object is shared across selected channels, as in the binary.
        for(int d=0;d<4;d++) {
            auto buffer=channels[d];
            if(distorted[d])distortion.process(buffer);
            if(pcfTarget==d+1)pcf.process(buffer,ticks);
            if(compressorTarget==d+2)compressor.process(buffer);
            float oldL=smoothL[d],oldR=smoothR[d];
            smoothL[d]=float(.93*oldL+.07*targetL[d]);smoothR[d]=float(.93*oldR+.07*targetR[d]);
            float incrementL=(smoothL[d]-oldL)/32,incrementR=(smoothR[d]-oldR)/32;
            for(int i=0;i<64;i++){left[i]+=buffer[i]*(oldL+(i/2)*incrementL);right[i]+=buffer[i]*(oldR+(i/2)*incrementR);send[i]+=buffer[i]*sendGain[d];}
        }
        delay.process(send,left,right,tempo);
        if(compressorTarget==1)compressor.process(left,right);
        masterSmooth=float(.93*masterSmooth+.07*masterTarget);
        for(int i=0;i<64;i++){left[i]*=masterSmooth;right[i]*=masterSmooth;}
    }
};
