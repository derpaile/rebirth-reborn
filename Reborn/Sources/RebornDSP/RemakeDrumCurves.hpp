#pragma once
// Procedural tone/decay curves for the remake's own synthesized sample bank.
static const std::array<float,8> bassPole808=[] {std::array<float,8> values{};for(int i=0;i<8;i++)values[i]=float(0.994*std::pow(1-i/7.0,1.7)+0.001);return values;}();
static const std::array<float,8> bassPole909=[] {std::array<float,8> values{};for(int i=0;i<8;i++)values[i]=float(0.92*std::pow(1-i/7.0,1.2)+0.001);return values;}();
static const std::array<float,16> bassDecay808=[] {std::array<float,16> values{};for(int i=0;i<16;i++)values[i]=float(std::exp(-2/(44100*(0.05+std::pow(i/15.0,2)*4))));return values;}();
