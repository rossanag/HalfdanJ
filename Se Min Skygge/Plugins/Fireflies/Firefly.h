#pragma once

#include "ofMain.h"
#include "ofxVectorMath.h"
#include "ofxNoise.h"

class Firefly {
public:
    Firefly();
    
    void update(float step, int frameNum);
    void draw(bool front);
    
    
    ofxVec3f pos;
    ofxVec3f a;
    ofxVec3f v;
    
    ofxPerlin *noise;

    
};