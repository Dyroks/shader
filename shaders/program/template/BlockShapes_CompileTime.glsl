 bool d(const vec3 v,const vec3 f,Ray m,inout float x,inout vec3 y)
 {
   vec3 i=m.inv_direction*(v-1e-05-m.origin),z=m.inv_direction*(f+1e-05-m.origin),c=min(z,i),s=max(z,i);
   float S=max(c.x,max(c.y,c.z));
   float t=min(s.x,min(s.y,s.z));
   bool e=min(t,x)>max(S,0.);
   if(e)
     y=-step(vec3(S),c)*sign(m.direction),x=S;
   return e;
 }
 bool c(vec3 v,float y,Ray f,inout float x,inout vec3 t)
 {
   bool i=false,m=false;
   y=round(y);
   #if RAYTRACE_GEOMETRY_QUALITY==0
   if(y>=67.)
     return false;
   m=d(v,v+vec3(1.,1.,1.),f,x,t);
   i=m;
   #else
   if(y<40.)
     {
       i=d(v,v+vec3(1.,1.,1.),f,x,t);
     }
   else if(abs(y-41.)<1.5)
     {
       vec3 r=vec3(0.);
       vec3 s=vec3(1.,.5,1.);
       s.y+=min((y-40.)*0.4375,.5);
       r.y+=max(0.,(y-41.)*.5);
       i=d(v+r,v+s,f,x,t);
     }
   if(abs(y-54.5)<12.)
     {
       float stairID=y-43.;
       float direction=mod(stairID,4.)*.5;
       float shape=mod(floor(stairID/4.),3.);
       vec3 baseOrigin=v;
       baseOrigin.y+=floor(stairID/12.)*.5;
       m=d(baseOrigin,baseOrigin+vec3(1.,.5,1.),f,x,t);
       i=i||m;
       if(shape<1.5)
         {
           float uDirection=floor(direction)*.5;
           vec3 origin=v,size=vec3(1.-uDirection,1.,.5+uDirection);
           origin.x+=max(.5-mod(direction-1.,2.),0.);
           origin.z+=max(.5-mod(direction-.5,2.),0.);
           m=d(origin,origin+size,f,x,t);
           i=i||m;
         }
       if(shape>.5)
         {
           vec3 origin=v,size=vec3(.5,1.,.5);
           origin.x+=floor(mod(direction+1.5,2.))*.5;
           origin.z+=fract(direction+.5);
           m=d(origin,origin+size,f,x,t);
           i=i||m;
         }
     }
   else if(abs(y-74.5)<8.)
     {
       m=d(v+vec3(6.,0.,6.)/16.,v+vec3(10.,16.,10.)/16.,f,x,t),i=i||m;
       float fenceID=y-67.0;
       float north=floor(fenceID/8.0)*.5;
       float south=floor(mod(fenceID,8.0)/4.0)*.5;
       float east=floor(mod(fenceID,4.0)/2.0)*.5;
       float west=mod(fenceID,2.0)*.5;
       float r=.5-west,s=.5+east;
       m=d(v+vec3(r,6./16.,7./16.),v+vec3(s,9./16.,9./16.),f,x,t);
       i=i||m;
       m=d(v+vec3(r,12./16.,7./16.),v+vec3(s,15./16.,9./16.),f,x,t);
       i=i||m;
       r=.5-north,s=.5+south;
       m=d(v+vec3(7./16.,6./16.,r),v+vec3(9./16.,9./16.,s),f,x,t);
       i=i||m;
       m=d(v+vec3(7./16.,12./16.,r),v+vec3(9./16.,15./16.,s),f,x,t);
       i=i||m;
     }
   else if(abs(y-84.5)<2.)
     {
       float direction=y-83.;
       float uDirection=floor(direction*.5);
       float sDirection=(direction-2.*uDirection)*13./16.;
       vec3 r=v+vec3(sDirection*uDirection,0.,(13./16.-sDirection)*uDirection);
       vec3 c=vec3(1.-sDirection,1,3./16.+sDirection);
       i=d(r,r+c,f,x,t);
     }
   else if(abs(y-87.5)<1.)
     {
       float s=13.0*step(87.5,y);
       vec3 r=vec3(0.,s/16.,0.);
       vec3 c=vec3(1.,(s+3.)/16.,1.);
       i=d(v+r,v+c,f,x,t);
     }
   else if(abs(y-96.)<8.||y==140.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y<=96.)
         {
           float n=y-88.;
           s.y=n*2./16.;
         }
       else if(y==97.)
         s.y=.0625;
       else if(abs(y-98.5)<1.)
         r=vec3(1.,0.,1.)/16.,s=vec3(15.,50.-y*.5,15.)/16.;
       else if(y==101.)
         s.y=9./16.;
       else if(y==102.||y==140.)
         s.y=13./16.;
       else if(y==103.)
         r=vec3(1.,0.,1.)/16.,s=vec3(15.,16.,15.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       if(y==140.)
         {
           vec3 r=vec3(0.),s=vec3(1.);
           r=vec3(4.,13.,4.)/16.,s=vec3(12.,16.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
     }
   #if RAYTRACE_GEOMETRY_QUALITY==2
   else if(abs(y-125.5)<8.)
     {
       float wallID=y-118.;
       m=d(v+vec3(4.,0.,4.)/16.,v+vec3(12.,16.,12.)/16.,f,x,t),i=i||m;
       float north=floor(wallID/8.0)*.5;
       float south=floor(mod(wallID,8.0)/4.0)*.5;
       float east=floor(mod(wallID,4.0)/2.0)*.5;
       float west=mod(wallID,2.0)*.5;
       float r=.5-west,s=.5+east;
       m=d(v+vec3(r,0.,5./16.),v+vec3(s,14./16.,11./16.),f,x,t);
       i=i||m;
       r=.5-north,s=.5+south;
       m=d(v+vec3(5./16.,0.,r),v+vec3(11./16.,14./16.,s),f,x,t);
       i=i||m;
     }
   else if(abs(y-136.5)<3.0)
     {
       float wallID=y-134.;
       float wallShape=mod(wallID,3.);
       float northSouth=1.-mod(wallShape,2.);
       float eastWest=min(wallShape,1.);
       float height=14.+2.*floor(wallID/3.);
       m=d(v+vec3(0.,0.,5.)/16.*eastWest,v+vec3(16.,height,11.)/16.*eastWest,f,x,t);
       i=i||m;
       m=d(v+vec3(5.,0.,0.)/16.*northSouth,v+vec3(11.,height,16.)/16.*northSouth,f,x,t);
       i=i||m;
     }
   else if(abs(y-234.5)<6.||abs(y-243.)<1.5)
     {
       float wallID=y-228.-step(241.,y);
       m=d(v+vec3(4.,0.,4.)/16.,v+vec3(12.,16.,12.)/16.,f,x,t),i=i||m;
       float north=floor(mod(wallID,16.0)/8.0)*.5;
       float south=floor(mod(wallID,8.0)/4.0)*.5;
       float east=floor(mod(wallID,4.0)/2.0)*.5;
       float west=mod(wallID,2.0)*.5;
       float r=.5-west,s=.5+east;
       m=d(v+vec3(r,0.,5./16.),v+vec3(s,1.,11./16.),f,x,t);
       i=i||m;
       r=.5-north,s=.5+south;
       m=d(v+vec3(5./16.,0.,r),v+vec3(11./16.,1.,s),f,x,t);
       i=i||m;
     }
   else if(abs(y-246.5)<2.)
     {
       float wallID=y-245.;
       m=d(v+vec3(4.,0.,4.)/16.,v+vec3(12.,16.,12.)/16.,f,x,t),i=i||m;
       float d1=mod(wallID,2.);
       float d2=floor(wallID*.5);
       m=d(v+vec3(0.,0.,5.)/16.*d2,v+vec3(8.,16.-2.*d1,11.)/16.*d2,f,x,t);
       i=i||m;
       m=d(v+vec3(8.,0.,5.)/16.*d2,v+vec3(16.,14.+2.*d1,11.)/16.*d2,f,x,t);
       i=i||m;
       m=d(v+vec3(5.,0.,0.)/16.*(1.-d2),v+vec3(11.,16.-2.*d1,8.)/16.*(1.-d2),f,x,t);
       i=i||m;
       m=d(v+vec3(5.,0.,8.)/16.*(1.-d2),v+vec3(11.,14.+2.*d1,16.)/16.*(1.-d2),f,x,t);
       i=i||m;
     }
   else if(abs(y-249.5)<1.)
     {
       float wallID=y-249.;
       m=d(v+vec3(0.,0.,5.)/16.,v+vec3(16.,14.+wallID*2.,11.)/16.,f,x,t);
       i=i||m;
       m=d(v+vec3(5.,0.,0.)/16.,v+vec3(11.,16.-wallID*2.,16.)/16.,f,x,t);
       i=i||m;
     }
   else if(abs(y-152.)<10.5)
     {
       float up=step(y,157.5);
       vec3 r=vec3(4.,0.+4.*step(158.5,y),4.)/16.,s=vec3(12.,12.+4.*(1.-up),12.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(5.,12.,5.)/16.,s=vec3(11.,14.,11.)/16.;
       m=d(v+r*up,v+s*up,f,x,t);
       i=i||m;
       float chorusID=y-142.+step(160.5,y)+3.*step(161.5,y);
       float north=floor(mod(chorusID,16.0)/8.0)*.5;
       float south=floor(mod(chorusID,8.0)/4.0)*.5;
       float east=floor(mod(chorusID,4.0)/2.0)*.5;
       float west=mod(chorusID,2.0)*.5;
       m=d(v+vec3(.5-west,.25,.25),v+vec3(.5+east,.75,.75),f,x,t);
       i=i||m;
       m=d(v+vec3(.25,.25,.5-north),v+vec3(.75,.75,.5+south),f,x,t);
       i=i||m;
     }
   else if(abs(y-227.5)<1.)
     {
       float d1=y-227.,d2=1.-d1;
       vec3 origin=v+vec3(d2*5.,0.,d1*5.)/16.,size=vec3(6.+d1*10.,1.,6.+d2*10.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin=v+vec3(d2,0.,d1)/16.,size=vec3(4.+d1*12.,4.,4.+d2*12.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin.xz+=vec2(10.*d2,10.*d1)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin=v+vec3(d1,3.,d2)/16.,size.xz=size.zx;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin.xz+=vec2(10.*d1,10.*d2)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(abs(y-104.5)<1.)
     {
       float d1=y-104.,d2=1.-d1;
       vec3 r=vec3(0.),s=vec3(1.);
       r=vec3(2.,0.,2.)/16.,s=vec3(14.,4.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(4.-d1,4.,4.-d2)/16.,s=vec3(12.+d1,5.,12.+d2)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(6.-2.*d1,5.,6.-2.*d2)/16.,s=vec3(10.+2.*d1,10.,10.+2.*d2)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(3.*d2,10.,3.*d1)/16.,s=vec3(13.+3.*d1,16.,13.+3.*d2)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(abs(y-111.5)<6.)
     {
       float p=y-106.;
       float north=mod(p,6.);
       float south=mod(p+5.,6.);
       float west=mod(p+4.,6.);
       float east=mod(p+3.,6.);
       float down=mod(p+2.,6.);
       float up=mod(p+1.,6.);
       float northSouth=step(1.5,north);
       float eastWest=step(1.5,west);
       float upDown=step(1.5,down);
       float offset=4./16.+floor(p/6.)*8./16.;
       m=d(v+offset*vec3(max(1.-west,0.),max(1.-down,0.),max(1.-north,0.)),v+vec3(1.)-offset*vec3(max(1.-east,0.),max(1.-up,0.),max(1.-south,0.)),f,x,t);
       i=i||m;
       m=d(v+6./16.*vec3(eastWest,upDown,northSouth),v+vec3(1.)-6./16.*vec3(eastWest,upDown,northSouth),f,x,t);
       i=i||m;
     }
   else if(y==141.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r=vec3(2.,0.,2.)/16.,s=vec3(14.,16.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(2.,2.,0.)/16.,s=vec3(14.,14.,16.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,2.,2.)/16.,s=vec3(16.,14.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(abs(y-164.5)<2.)
     {
       float grindStoneID=y-163.;
       float axisZ=floor(grindStoneID*.5);
       float axisY=1.0-axisZ;
       float facing=mod(grindStoneID,2.0)*3.0;
       float stoneOffsetY=(grindStoneID*4.-2.)*axisY;
       float baseOffsetY=stoneOffsetY*3.-facing*axisY;
       float stoneOffsetZ=(grindStoneID*4.-10.)*axisZ;
       float baseOffsetZ=stoneOffsetZ*3.-facing*axisZ;
       vec3 origin=v+vec3(4.,2.-stoneOffsetY,2.-stoneOffsetZ)/16.,size=vec3(8.,12.,12.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin+=vec3(-2.,3.,3.)/16.,size=vec3(12.,6.,6.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin=v+vec3(2.,6.+baseOffsetY,6.+baseOffsetZ)/16.,size=vec3(2.,4.+axisY*3.,4.+axisZ*3.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin.x+=10./16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(abs(y-168.5)<2.)
     {
       float grindStoneID=y-167.;
       float axisX=floor(grindStoneID*.5);
       float axisY=1.0-axisX;
       float facing=mod(grindStoneID,2.0)*3.0;
       float stoneOffsetY=(grindStoneID*4.-2.)*axisY;
       float baseOffsetY=stoneOffsetY*3.-facing*axisY;
       float stoneOffsetX=(grindStoneID*4.-10.)*axisX;
       float baseOffsetX=stoneOffsetX*3.-facing*axisX;
       vec3 origin=v+vec3(2.-stoneOffsetX,2.-stoneOffsetY,4.)/16.,size=vec3(12.,12.,8.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin+=vec3(3.,3.,-2.)/16.,size=vec3(6.,6.,12.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin=v+vec3(6.+baseOffsetX,6.+baseOffsetY,2.)/16.,size=vec3(4.+axisX*3.,4.+axisY*3.,2.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
       origin.z+=10./16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(y==171.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r=vec3(5.,0.,5.)/16.,s=vec3(11.,4.,11.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(5.,4.,5.)/16.,s=vec3(6.,6.,11.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       s=vec3(11.,6.,6.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(5.,4.,10.)/16.,s=vec3(11.,6.,11.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(10.,4.,5.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(y==172.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       s.y=2./16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r.y=2./16.,s=vec3(1.,1.,2./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,2./16.,0.),s=vec3(2./16.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,2.,14.)/16.,s.x=1.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,2.,0.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(y==173.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r.y=3./16.,s.y=4./16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r.y=4./16.,s=vec3(1.,1.,2./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       s=vec3(2./16.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,4.,14.)/16.,s=vec3(1.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,4.,0.)/16.,s=vec3(1.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,0.,0.),s=vec3(2.,3.,4.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       s=vec3(4.,3.,2.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,0.,12./16.),s=vec3(2.,3.,16.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,0.,14./16.),s=vec3(4.,3.,16.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(12./16.,0.,0.),s=vec3(16.,3.,2.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14./16.,0.,0.),s=vec3(16.,3.,4.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(12.,0.,14.)/16.,s=vec3(1.,3./16.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,0.,12.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(abs(y-176)<3.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r.y=10./16.,s.y=11./16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,11./16.,0.),s=vec3(1.,1.,2./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,11./16.,0.),s=vec3(2./16.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,11.,14.)/16.,s=vec3(1.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,11.,0.)/16.,s=vec3(1.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(4.,4.,4.)/16.,s=vec3(12.,10.,12.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       float h=y-174.;
       float a=12.*mod(h,2.)-6.;
       r=vec3(6.+a*step(2.5,h),4.-max(1.-h,0.)*4.,6.-a*step(abs(h-1.5),1.))/16.,s=r+vec3(4./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(abs(y-182.5)<4.)
     {
       float buttonID=y-179.;
       float shape=mod(buttonID,2.);
       float direction=floor(mod(buttonID*.5,2.));
       float powered=floor(buttonID*.25);
       vec3 origin=v+vec3(5.+shape,16.*direction,6.-shape)/16.;
       vec3 size=vec3(6.-2.*shape,(1.-direction*2.)*(2.-powered),4.+2.*shape)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(abs(y-188.5)<2.)
     {
       float buttonID=y-187.;
       float direction=1.-mod(buttonID,2.);
       float powered=floor(buttonID*.5);
       vec3 origin=v+vec3(5./16.,6./16.,direction);
       vec3 size=vec3(6.,4.,(1.-direction*2.)*(2.-powered))/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(abs(y-192.5)<2.)
     {
       float buttonID=y-191.;
       float direction=mod(buttonID,2.);
       float powered=floor(buttonID*.5);
       vec3 origin=v+vec3(direction,6./16.,5./16.);
       vec3 size=vec3((1.-direction*2.)*(2.-powered),4.,6.)/16.;
       m=d(origin,origin+size,f,x,t);
       i=i||m;
     }
   else if(y==195)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       s=vec3(1.,2./16.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(4.,2.,4.)/16.,s=vec3(12.,15.,12.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   else if(abs(y-198.5)<3.)
     {
       float gateID=y-196.;
       float type=mod(gateID,3.);
       float height=-floor(gateID/3.)*3.;
       vec3 r=v+vec3(0.,5.+height,7.)/16.;
       m=d(r,r+vec3(2.,11.,2.)/16.,f,x,t);
       i=i||m;
       r.x+=14./16.;
       m=d(r,r+vec3(2.,11.,2.)/16.,f,x,t);
       i=i||m;
       if(type<.5)
         {
           r=v+vec3(2.,6.+height,7.)/16.;
           m=d(r,r+vec3(12.,3.,2.)/16.,f,x,t);
           i=i||m;
           r.y+=6./16.;
           m=d(r,r+vec3(12.,3.,2.)/16.,f,x,t);
           i=i||m;
           r.xy+=vec2(4., -3.)/16.;
           m=d(r,r+vec3(4.,3.,2.)/16.,f,x,t);
           i=i||m;
         }
       else
         {
           float direction=2.*type-3.;
           vec3 origin=v+vec3(0.,0.,.5),size=vec3(2.,3.,direction*4.)/16.;
           r=origin+vec3(0.,6.+height,direction)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.x+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.xy+=vec2(-14.,6.)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.x+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r=origin+vec3(0.,6.+height,direction*5.)/16.,size=vec3(2.,9.,direction*2.)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.x+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
         }
     }
   else if(abs(y-204.5)<3.)
     {
       float gateID=y-202.;
       float type=mod(gateID,3.);
       float height=-floor(gateID/3.)*3.;
       vec3 r=v+vec3(7.,5.+height,0.)/16.;
       m=d(r,r+vec3(2.,11.,2.)/16.,f,x,t);
       i=i||m;
       r.z+=14./16.;
       m=d(r,r+vec3(2.,11.,2.)/16.,f,x,t);
       i=i||m;
       if(type<.5)
         {
           r=v+vec3(7.,6.+height,2.)/16.;
           m=d(r,r+vec3(2.,3.,12.)/16.,f,x,t);
           i=i||m;
           r.y+=6./16.;
           m=d(r,r+vec3(2.,3.,12.)/16.,f,x,t);
           i=i||m;
           r.yz+=vec2(-3.,4.)/16.;
           m=d(r,r+vec3(2.,3.,4.)/16.,f,x,t);
           i=i||m;
         }
       else
         {
           float direction=2.*type-3.;
           vec3 origin=v+vec3(.5,0.,0.),size=vec3(direction*4.,3.,2.)/16.;
           r=origin+vec3(direction,6.+height,0.)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.z+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.yz+=vec2(6.,-14.)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.z+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r=origin+vec3(direction*5.,6.+height,0.)/16.,size=vec3(direction*2.,9.,2.)/16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
           r.z+=14./16.;
           m=d(r,r+size,f,x,t);
           i=i||m;
         }
     }
   else if(abs(y-208.5)<1.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r.y=1.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r.y=0.,s=vec3(2.,16.,2.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,0.,14./16.),s=vec3(2./16.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14./16.,0.,0.),s=vec3(1.,1.,2./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,0.,14.)/16.,s=vec3(1.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(0.,14.,2.)/16.,s=vec3(2.,16.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(2.,14.,0.)/16.,s=vec3(14.,16.,2.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(14.,14.,2.)/16.,s=vec3(1.,1.,14./16.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(2.,14.,14.)/16.,s=vec3(14./16.,1.,1.);
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       if(y==209.)
         {
           r=vec3(2.,2.,2.)/16.,s=vec3(14.,2.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,0.,2./16.),s=vec3(2.,2.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2./16.,0.,0.),s=vec3(14.,2.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,0.,2.)/16.,s=vec3(16.,2.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,0.,14.)/16.,s=vec3(14.,2.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
     }
   else if(abs(y-214.)<5.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r=vec3(4.,4.,4.)/16.,s=vec3(12.,6.,12.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(5.,6.,5.)/16.,s=vec3(11.,13.,11.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       if(y==210.)
         {
           r=vec3(0.,0.,6./16.),s=vec3(2.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,0.,6.)/16.,s=vec3(1.,1.,10./16.);
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,13.,7.)/16.,s=vec3(14.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==211.)
         {
           r=vec3(6./16.,0.,0.),s=vec3(10.,16.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,0.,14.)/16.,s=vec3(10./16.,1.,1.);
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,13.,2.)/16.,s=vec3(9.,15.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==212.)
         {
           r=vec3(7.,13.,0.)/16.,s=vec3(9.,15.,13.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==213.)
         {
           r=vec3(7.,13.,3.)/16.,s=vec3(9.,15.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==214.)
         {
           r=vec3(3.,13.,7.)/16.,s=vec3(16.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==215.)
         {
           r=vec3(0.,13.,7.)/16.,s=vec3(13.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==216.)
         {
           r=vec3(7.,13.,0.)/16.,s=vec3(9.,15.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==217.)
         {
           r=vec3(0.,13.,7.)/16.,s=vec3(16.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else
         {
           r=vec3(7.,13.,7.)/16.,s=vec3(9.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
     }
   else if(abs(y-222.)<4.)
     {
       float r=2.*(y-219)+1.;
       r/=16.;
       m=d(v+vec3(r,0.,1./16.),v+vec3(15.,8.,15.)/16,f,x,t);
       i=i||m;
     }
   else if(y==226.)
     {
       vec3 r=vec3(3.,0.,3.)/16.,s=vec3(13.,13.,13.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(2.,1.,2.)/16.,s=vec3(14.,11.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(1.,3.,1.)/16.,s=vec3(15.,8.,15.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(5.,13.,5.)/16.,s=vec3(11.,15.,11.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       r=vec3(6.,15.,6.)/16.,s=vec3(10.,16.,10.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
     }
   #endif
   #endif
   return i;
 }
