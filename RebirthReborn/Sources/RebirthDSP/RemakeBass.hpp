#pragma once
// Independent band-limited oscillator and nonlinear ladder-style bass voice.
// Every coefficient is calculated here; there is no original ROM or DSP dump.
struct Bass {
    uint8_t controls[9]={1,0,64,64,48,64,64,64,0};
    bool outgoingSlide=false,highQuality=true;
    float output[64]{};
    double phase=0,hz=110,targetHz=110,amp=0,env=0,accentGain=1;
    double filter[4]{},cutoff=700,previousIn=0,previousOut=0;
    bool gate=false;
    void reset(bool preserve=false){
        uint8_t saved[9];std::memcpy(saved,controls,9);
        const uint8_t initial[9]={1,0,64,64,48,64,64,64,0};std::memcpy(controls,preserve?saved:initial,9);
        phase=0;hz=targetHz=110;amp=env=0;accentGain=1;gate=false;outgoingSlide=false;cutoff=700;previousIn=previousOut=0;
        std::fill(std::begin(filter),std::end(filter),0);std::fill(std::begin(output),std::end(output),0);
    }
    void note(int midi,bool accent,bool slide,bool rest=false){
        const bool legato=outgoingSlide && gate;
        const double tuning=(int(controls[2])-64)*12.0/64;
        targetHz=440*std::pow(2.0,(midi-69+tuning)/12);
        if(!legato)hz=targetHz;
        if(rest){release();return;}
        gate=true;
        if(!legato){amp=1;env=1;accentGain=accent?1+controls[7]/127.0*0.8:1;}
        outgoingSlide=slide;
    }
    void release(){if(!outgoingSlide)gate=false;}
    void rest(){outgoingSlide=false;gate=false;}
    static double blep(double t,double width){
        if(t<width){t/=width;return t+t-t*t-1;}
        if(t>1-width){t=(t-1)/width;return t*t+t+t+1;}
        return 0;
    }
    void render(){
        const int oversampling=highQuality?2:1;
        const double sampleRate=44100.0*oversampling;
        const double envDecay=std::exp(-1/(sampleRate*(0.045+controls[6]/127.0*1.25)));
        const double ampDecay=std::exp(-1/(sampleRate*(gate?2.2:0.018)));
        const double base=80*std::pow(70.0,controls[3]/127.0);
        const double resonance=controls[4]/127.0;
        for(int i=0;i<64;i++){
            double mixed=0;
            for(int sub=0;sub<oversampling;sub++){
                hz+=(targetHz-hz)*0.002/oversampling;
                const double width=std::clamp(hz/sampleRate,0.00001,0.25);
                phase+=width;if(phase>=1)phase-=1;
                double wave=2*phase-1-blep(phase,width);
                if(controls[8]){double shifted=phase+0.5;if(shifted>=1)shifted-=1;wave=(phase<0.5?1:-1)+blep(phase,width)-blep(shifted,width);}
                amp*=ampDecay;env*=envDecay;
                const double target=std::clamp(base+env*(controls[5]/127.0)*10500*accentGain,45.0,16000.0);
                cutoff+=(target-cutoff)*0.002/oversampling;
                const double coefficient=1-std::exp(-6.283185307179586*cutoff/sampleRate);
                double x=std::tanh(wave*0.7-resonance*3.8*filter[3]);
                for(int pole=0;pole<4;pole++){filter[pole]+=coefficient*(x-std::tanh(filter[pole]));x=filter[pole];}
                const double value=x*amp*accentGain*0.7;
                const double dc=value-previousIn+0.997*previousOut;previousIn=value;previousOut=dc;mixed+=dc;
            }
            output[i]=float(mixed/oversampling);
        }
    }
};
