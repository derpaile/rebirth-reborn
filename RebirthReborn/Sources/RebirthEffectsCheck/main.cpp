#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include "../RebirthDSP/RemakeEffects.hpp"
void require(bool value,const char *label){if(!value){std::cerr<<"FAIL: "<<label<<'\n';std::exit(1);}}
int main(){
    float l[64],r[64];
    for(int shape:{0,1,64,127})for(int amount:{0,64,127}){
        RemakeDistortion effect;effect.controls[1]=amount;effect.controls[2]=shape;
        for(int block=0;block<64;block++){for(int i=0;i<64;i++)l[i]=float(std::sin((block*64+i)*0.07)*2);effect.process(l);for(float x:l)require(std::isfinite(x),"Distortion stays finite");}
    }
    RemakeCompressor compressor;
    for(int block=0;block<128;block++){std::fill(l,l+64,2);std::fill(r,r+64,4);compressor.process(l,r);for(int i=0;i<64;i++)require(std::abs(r[i]-2*l[i])<1e-6,"Stereo compressor preserves channel ratio");}
    for(int pattern=0;pattern<55;pattern++)for(int mode=0;mode<2;mode++)for(int control:{0,127}){
        RemakePCF pcf;pcf.controls[4]=pattern;pcf.controls[6]=mode;pcf.controls[1]=pcf.controls[2]=pcf.controls[3]=pcf.controls[5]=control;
        for(int block=0;block<128;block++){for(int i=0;i<64;i++)l[i]=float(std::sin((block*64+i)*0.07)*0.05);pcf.process(l,int64_t(block*64*384.0/44100));for(float x:l)require(std::isfinite(x)&&std::abs(x)<100,"Procedural PCF patterns stay bounded");}
    }
    for(int mode=0;mode<2;mode++){
        auto delay=new RemakeDelay;delay->controls[1]=1;delay->controls[2]=mode;delay->controls[3]=0;
        int first=-1;float send[64];
        for(int block=0;block<140;block++){std::fill(l,l+64,0);std::fill(r,r+64,0);std::fill(send,send+64,0);if(block==0)send[0]=1;delay->process(send,l,r,120);for(int i=0;i<64;i++)if(l[i]>0.001 && first<0)first=block*64+i;}
        require(first==(mode?5512:7350),"Delay matches selected musical subdivision");delete delay;
    }
    std::cout<<"PASS: procedural distortion, linked compression, 55 generated filter patterns at both extremes and modes, delay subdivisions.\n";
}
