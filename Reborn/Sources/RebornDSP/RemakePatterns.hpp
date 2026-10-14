#pragma once
#include <array>
#include <cmath>
#include <cstdint>
// 55 fresh rhythms and motion shapes, generated independently of any ROM.
static float distortionGain(int shape,int amount){return float(0.85/(1+shape*0.65+amount*1.1));}
static const std::array<float,16> pcfDecay=[] {std::array<float,16> values{};for(int i=0;i<16;i++)values[i]=float(std::exp(-1/(80+std::pow(i/15.0,2)*30000)));return values;}();
static const std::array<uint16_t,55> pcfLengths=[] {std::array<uint16_t,55> values{};for(int i=0;i<55;i++)values[i]=i<20?16:i<35?32:uint16_t(3+(i*7)%29);return values;}();
static const std::array<uint16_t,55> pcfDivisions=[] {std::array<uint16_t,55> values{};for(int i=0;i<55;i++)values[i]=i<35?16:32;return values;}();
static const std::array<std::array<uint8_t,32>,55> pcfEvents=[] {
    std::array<std::array<uint8_t,32>,55> values{};uint32_t seed=0x5245424f;
    for(int pattern=0;pattern<55;pattern++)for(int step=0;step<pcfLengths[pattern];step++){
        const int length=pcfLengths[pattern];
        if(pattern<20){const int pulses=1+pattern%12;if((step*pulses)%length<pulses)values[pattern][step]=uint8_t(120-(step%4)*12);}
        else if(pattern<35){const double phase=double(step)/length;const double motion=pattern%2?phase:1-std::abs(phase*2-1);values[pattern][step]=uint8_t(1+2*int(motion*58));}
        else{seed=seed*1664525u+1013904223u;values[pattern][step]=(seed>>28)>5?uint8_t(30+((seed>>16)%90)):0;}
    }
    return values;
}();
