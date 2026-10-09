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
   y=round(y);
   bool i=false,m=false;
   #if RAYTRACE_GEOMETRY_QUALITY==0
   if(y>=67.)
     return false;
   m=d(v,v+vec3(1.,1.,1.),f,x,t);
   i=m;
   #else
   if(y<40.)
     {
       return m=d(v,v+vec3(1.,1.,1.),f,x,t),m;
     }
   else if(y==40.||y==41.||abs(y-48.5)<6.)
     {
       float r=.5;
       if(y==41.)
         r=.9375;
       m=d(v,v+vec3(1.,r,1.),f,x,t);
       i=i||m;
       if(y<42.)
         return i;
     }
   if(y==42.||abs(y-60.5)<6.)
     {
       m=d(v+vec3(0.,.5,0.),v+vec3(1.,1.,1.),f,x,t),i=i||m;
       if(y<43.)
         return i;
     }
   if(abs(y-54.5)<12.)
     {
       float mody12=mod(y,12.);
       if(mody12!=3.&&mody12!=5.&&mody12!=8.)
         {
           float mody3=mod(y,3),s=.5,e=.5;
           if(mody12!=1.&&mody12!=6.&&mody12!=9.)
             s=0.;
           if(mody12!=0.&&mody12!=4.&&mody12!=10.)
             e=1.;
           m=d(v+vec3(s,0.,0.),v+vec3(e,1.,.5),f,x,t);
           i=i||m;
         }
       if(mody12!=4.&&mody12!=6.&&mody12!=7.)
         {
           float s=.5,e=.5;
           if(mody12!=3.&&mody12!=9.&&mody12!=11.)
             s=0.;
           if(mody12!=2.&&mody12!=5.&&mody12!=10.)
             e=1.;
           m=d(v+vec3(s,0.,.5),v+vec3(e,1.,1.),f,x,t);
           i=i||m;
         }
       return i;
     }
   if(abs(y-74.5)<8.)
     {
       float mody4=mod(y,4);
       m=d(v+vec3(6.,0.,6.)/16.,v+vec3(10.,16.,10.)/16.,f,x,t),i=i||m;
       if(mody4!=3.)
         {
           float mody2=mod(y,2),r=8.,s=8.;
           if(mody2==0.)
             r=0.;
           if(mody4!=0.)
             s=16.;
           m=d(v+vec3(r,6.,7.)/16.,v+vec3(s,9.,9.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(r,12.,7.)/16.,v+vec3(s,15.,9.)/16.,f,x,t);
           i=i||m;
         }
       if(y>=71.)
         {
           float r=8.,w=8.;
           if(abs(y-76.5)>2.)
             w=16.;
           if(y>=75.)
             r=0.;
           m=d(v+vec3(7.,6.,r)/16.,v+vec3(9.,9.,w)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(7.,12.,r)/16.,v+vec3(9.,15.,w)/16.,f,x,t);
           i=i||m;
         }
       return i;
     }
   else if(abs(y-84.5)<2.)
     {
       vec3 r=vec3(0,0,0),c=vec3(1,1,3./16.);
       if(y==84.)
         c.xz=vec2(3./16.,1);
       else if(y==86.)
         r.x=13./16.,c.z=1.;
       else if(y==85.)
         r.z=13./16.,c.z=1.;
       m=d(v+r,v+c,f,x,t);
       i=i||m;
       return i;
     }
   else if(abs(y-87.5)<1.)
     {
       vec3 r=vec3(0.),c=vec3(1.);
       float s=0.;
       if(y==88.)
         s=13.;
       r.y=s/16.;
       c.y=(s+3.)/16.;
       m=d(v+r,v+c,f,x,t);
       i=i||m;
       return i;
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
       else if(y==98.)
         r=vec3(1.,0.,1.)/16.,s=vec3(15.,1.,15.)/16.;
       else if(y==99.)
         r=vec3(1.,0.,1.)/16.,s=vec3(15.,.5,15.)/16.;
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
       return i;
     }
   #if RAYTRACE_GEOMETRY_QUALITY==2
   else if(abs(y-128.5)<11.||y>=229.)
     {
       float lowWallID=y-118.;
       bool up=y<=133.;
       bool lowNS=y==134||y==136||y==250.;
       bool lowEW=y==135||y==136||y==249.;
       bool lowNorth=(    lowWallID     >7.5&&up)||lowNS||y==246.;
       bool lowSouth=(mod(lowWallID, 8.)>3.5&&up)||lowNS||y==245.;
       bool lowEast =(mod(lowWallID, 4.)>1.5&&up)||lowEW||y==247.;
       bool lowWest =(mod(lowWallID, 2.)>0.5&&up)||lowEW||y==248.;
       float highWallID=y-228.-step(241.,y);
       bool allHigh=abs(y-236.5)<8.;
       bool highNS=y==137||y==139||y==249.;
       bool highEW=y==138||y==139||y==250.;
       bool highNorth=(    highWallID     >7.5&&allHigh)||highNS||y==245.;
       bool highSouth=(mod(highWallID, 8.)>3.5&&allHigh)||highNS||y==246.;
       bool highEast =(mod(highWallID, 4.)>1.5&&allHigh)||highEW||y==248.;
       bool highWest =(mod(highWallID, 2.)>0.5&&allHigh)||highEW||y==247.;
       if(up||abs(y-238.5)<10)
         {
           m=d(v+vec3(4.,0.,4.)/16.,v+vec3(12.,16.,12.)/16.,f,x,t);
           i=i||m;
         }
       if(lowNorth||lowSouth)
         {
           float r=.5,s=.5;
           if(lowNorth)
             r=0.;
           if(lowSouth)
             s=1.;
           m=d(v+vec3(5./16.,0.,r),v+vec3(11./16.,14./16.,s),f,x,t);
           i=i||m;
         }
       if(lowEast||lowWest)
         {
           float r=.5,s=.5;
           if(lowWest)
             r=0.;
           if(lowEast)
             s=1.;
           m=d(v+vec3(r,0.,5./16.),v+vec3(s,14./16.,11./16.),f,x,t);
           i=i||m;
         }
       if(highNorth||highSouth)
         {
           float r=.5,s=.5;
           if(highNorth)
             r=0.;
           if(highSouth)
             s=1.;
           m=d(v+vec3(5./16.,0.,r),v+vec3(11./16.,1.,s),f,x,t);
           i=i||m;
         }
       if(highEast||highWest)
         {
           float r=.5,s=.5;
           if(highWest)
             r=0.;
           if(highEast)
             s=1.;
           m=d(v+vec3(r,0.,5./16.),v+vec3(s,1.,11./16.),f,x,t);
           i=i||m;
         }
       return i;
     }
   else if(abs(y-152.)<11.)
     {
       bool down=y<=157.;
       if(down)
         {
           vec3 r=vec3(4.,0.,4.)/16.,s=vec3(12.,12.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(5.,12.,5.)/16.,s=vec3(11.,14.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       else if(y==158.)
         {
           vec3 r=vec3(4.,0.,4.)/16.,s=vec3(12.,16.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y>=159.)
         {
           vec3 r=vec3(0.),s=vec3(1.);
           r=vec3(4.,4.,4.)/16.,s=vec3(12.,16.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
         }
       float chorusID=y-142.;
       bool north=(    chorusID     >7.5&&down)||y==162.;
       bool south=(mod(chorusID, 8.)>3.5&&down)||y==161.;
       bool east =(mod(chorusID, 4.)>1.5&&down)||y==160.;
       bool west =(mod(chorusID, 2.)>0.5&&down)||y==159.;
       if(north||south)
         {
           float r=8.,s=8.;
           if(north)
             r=0.;
           if(south)
             s=16.;
           m=d(v+vec3(4.,4.,r)/16.,v+vec3(12.,12.,s)/16.,f,x,t);
           i=i||m;
         }
       if(east||west)
         {
           float r=8.,s=8.;
           if(west)
             r=0.;
           if(east)
             s=16.;
           m=d(v+vec3(r,4.,4.)/16.,v+vec3(s,12.,12.)/16.,f,x,t);
           i=i||m;
         }
       return i;
     }
   else if(abs(y-227.5)<1.)
     {
       if(y==227.)
         {
           m=d(v+vec3(5./16.,0.,0.),v+vec3(11.,1.,16.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(1./16.,0.,0.),v+vec3(5.,4.,16.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(11./16.,0.,0.),v+vec3(15.,4.,16.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(0.,3.,1.)/16.,v+vec3(16.,7.,5.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(0.,3.,11.)/16.,v+vec3(16.,7.,15.)/16.,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           m=d(v+vec3(0.,0.,5./16.),v+vec3(16.,1.,11.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(0.,0.,1./16.),v+vec3(16.,4.,5.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(0.,0.,11./16.),v+vec3(16.,4.,15.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(1.,3.,0.)/16.,v+vec3(5.,7.,16.)/16.,f,x,t);
           i=i||m;
           m=d(v+vec3(11.,3.,0.)/16.,v+vec3(15.,7.,16.)/16.,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-104.5)<1.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       r=vec3(2.,0.,2.)/16.,s=vec3(14.,4.,14.)/16.;
       m=d(v+r,v+s,f,x,t);
       i=i||m;
       if(y==104.)
         {
           r=vec3(4.,4.,3.)/16.,s=vec3(12.,5.,13.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,5.,4.)/16.,s=vec3(10.,10.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(3.,10.,0.)/16.,s=vec3(13./16.,1.,1.);
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           r=vec3(3.,4.,4.)/16.,s=vec3(13.,5.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,5.,6.)/16.,s=vec3(12.,10.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,10.,3.)/16.,s=vec3(1.,1.,13./16.);
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-108.5)<3.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==106.)
         {
           r.z=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,6.,0.)/16.,s=vec3(10.,10.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==107.)
         {
           s.z=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,6.,12.)/16.,s=vec3(10.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==108.)
         {
           r.x=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,6.,6.)/16.,s=vec3(4.,10.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==109.)
         {
           s.x=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(12.,6.,6.)/16.,s=vec3(16.,10.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==110.)
         {
           r.y=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,0.,6.)/16.,s=vec3(10.,4.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           s.y=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,12.,6.)/16.,s=vec3(10.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-114.5)<3.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==112.)
         {
           r.z=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,6.,0.)/16.,s=vec3(10.,10.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==113.)
         {
           s.z=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,6.,4.)/16.,s=vec3(10.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==114.)
         {
           r.x=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,6.,6.)/16.,s=vec3(12.,10.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==115.)
         {
           s.x=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,6.,6.)/16.,s=vec3(16.,10.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==116.)
         {
           r.y=12./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,0.,6.)/16.,s=vec3(10.,12.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           s.y=4./16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,4.,6.)/16.,s=vec3(10.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
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
       return i;
     }
   else if(abs(y-166.5)<4.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==163.)
         {
           r=vec3(2.,0.,6.)/16.,s=vec3(4.,7.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(12.,0.,6.)/16.,s=vec3(14.,7.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,7.,5.)/16.,s=vec3(14.,13.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,4.,2.)/16.,s=vec3(12.,16.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==164.)
         {
           r=vec3(2.,9.,6.)/16.,s=vec3(4.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(12.,9.,6.)/16.,s=vec3(14.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,3.,5.)/16.,s=vec3(14.,9.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,0.,2.)/16.,s=vec3(12.,12.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==165.)
         {
           r=vec3(12.,6.,0.)/16.,s=vec3(14.,10.,7.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,6.,0.)/16.,s=vec3(4.,10.,7.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,5.,7.)/16.,s=vec3(14.,11.,13.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,2.,4.)/16.,s=vec3(12.,14.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==166.)
         {
           r=vec3(12.,6.,9.)/16.,s=vec3(14.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,6.,9.)/16.,s=vec3(4.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,5.,3.)/16.,s=vec3(14.,11.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,2.,0.)/16.,s=vec3(12.,14.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==167.)
         {
           r=vec3(6.,0.,2.)/16.,s=vec3(10.,7.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,0.,12.)/16.,s=vec3(10.,7.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(5.,7.,2.)/16.,s=vec3(11.,13.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,4.,4.)/16.,s=vec3(14.,16.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==168.)
         {
           r=vec3(6.,9.,2.)/16.,s=vec3(10.,16.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,9.,12.)/16.,s=vec3(10.,16.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(5.,3.,2.)/16.,s=vec3(11.,9.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,0.,4.)/16.,s=vec3(14.,12.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==169.)
         {
           r=vec3(0.,6.,12.)/16.,s=vec3(7.,10.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,6.,2.)/16.,s=vec3(7.,10.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,5.,2.)/16.,s=vec3(13.,11.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(4.,2.,4.)/16.,s=vec3(16.,14.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           r=vec3(9.,6.,12.)/16.,s=vec3(16.,10.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(9.,6.,2.)/16.,s=vec3(16.,10.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(3.,5.,2.)/16.,s=vec3(9.,11.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(0.,2.,4.)/16.,s=vec3(12.,14.,12.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-172)<2.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==171.)
         {
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
           return i;
         }
       else if(y==172.)
         {
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
           return i;
         }
       else
         {
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
           return i;
         }
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
       r=vec3(6.,0.,6.)/16.,s=vec3(10.,4.,10.)/16.;
       if(y==175.)
         {
           r.yz=vec2(4.,0.)/16.,s.yz=vec2(8.,4.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==176.)
         {
           r.yz=vec2(4.,12.)/16.,s.yz=vec2(8.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==177.)
         {
           r.xy=vec2(12.,4.)/16.,s.xy=vec2(16.,8.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==178.)
         {
           r.xy=vec2(0.,4.)/16.,s.xy=vec2(4.,8.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-186.5)<8.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==179)
         {
           r=vec3(5.,0.,6.)/16.,s=vec3(11.,2.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==180)
         {
           r=vec3(6.,0.,5.)/16.,s=vec3(10.,2.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==181.)
         {
           r=vec3(5.,14.,6.)/16.,s=vec3(11.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==182.)
         {
           r=vec3(6.,14.,5.)/16.,s=vec3(10.,16.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==183.)
         {
           r=vec3(5.,0.,6.)/16.,s=vec3(11.,1.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==184.)
         {
           r=vec3(6.,0.,5.)/16.,s=vec3(10.,1.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==185.)
         {
           r=vec3(5.,15.,6.)/16.,s=vec3(11.,16.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==186.)
         {
           r=vec3(6.,15.,5.)/16.,s=vec3(10.,16.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==187)
         {
           r=vec3(5.,6.,14.)/16.,s=vec3(11.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==188)
         {
           r=vec3(5.,6.,0.)/16.,s=vec3(11.,10.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==189.)
         {
           r=vec3(5.,6.,15.)/16.,s=vec3(11.,10.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==190.)
         {
           r=vec3(5.,6.,0.)/16.,s=vec3(11.,10.,1.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==191.)
         {
           r=vec3(0.,6.,5.)/16.,s=vec3(2.,10.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==192.)
         {
           r=vec3(14.,6.,5.)/16.,s=vec3(16.,10.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==193.)
         {
           r=vec3(0.,6.,5.)/16.,s=vec3(1.,10.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           r=vec3(15.,6.,5.)/16.,s=vec3(16.,10.,11.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
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
       return i;
     }
   else if(abs(y-201.5)<6.)
     {
       vec3 r=vec3(0.),s=vec3(1.);
       if(y==196)
         {
           r=vec3(0.,5.,7.)/16.,s=vec3(2.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,5.,7.)/16.,s=vec3(16.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,6.,7.)/16.,s=vec3(14.,9.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,12.,7.)/16.,s=vec3(14.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,9.,7.)/16.,s=vec3(10.,12.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(abs(y-197.5)<1.)
         {
           r=vec3(0.,5.,7.)/16.,s=vec3(2.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,5.,7.)/16.,s=vec3(16.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           if(y==197.)
             {
               r=vec3(0.,12.,3.)/16.,s=vec3(2.,15.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,12.,3.)/16.,s=vec3(16.,15.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,6.,3.)/16.,s=vec3(2.,9.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,6.,3.)/16.,s=vec3(16.,9.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,6.,1.)/16.,s=vec3(2.,15.,3.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,6.,1.)/16.,s=vec3(16.,15.,3.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
           else
             {
               r=vec3(0.,12.,9.)/16.,s=vec3(2.,15.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,12.,9.)/16.,s=vec3(16.,15.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,6.,9.)/16.,s=vec3(2.,9.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,6.,9.)/16.,s=vec3(16.,9.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,6.,13.)/16.,s=vec3(2.,15.,15.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,6.,13.)/16.,s=vec3(16.,15.,15.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
         }
       else if(y==199)
         {
           r=vec3(0.,2.,7.)/16.,s=vec3(2.,13.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,2.,7.)/16.,s=vec3(16.,13.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,3.,7.)/16.,s=vec3(14.,6.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(2.,9.,7.)/16.,s=vec3(14.,12.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(6.,6.,7.)/16.,s=vec3(10.,9.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(abs(y-200.5)<1.)
         {
           r=vec3(0.,2.,7.)/16.,s=vec3(2.,13.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(14.,2.,7.)/16.,s=vec3(16.,13.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           if(y==200.)
             {
               r=vec3(0.,9.,3.)/16.,s=vec3(2.,12.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,9.,3.)/16.,s=vec3(16.,12.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,3.,3.)/16.,s=vec3(2.,6.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,3.,3.)/16.,s=vec3(16.,6.,7.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,3.,1.)/16.,s=vec3(2.,12.,3.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,3.,1.)/16.,s=vec3(16.,12.,3.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
           else
             {
               r=vec3(0.,9.,9.)/16.,s=vec3(2.,12.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,9.,9.)/16.,s=vec3(16.,12.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,3.,9.)/16.,s=vec3(2.,6.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,3.,9.)/16.,s=vec3(16.,6.,13.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(0.,3.,13.)/16.,s=vec3(2.,12.,15.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(14.,3.,13.)/16.,s=vec3(16.,12.,15.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
         }
       else if(y==202)
         {
           r=vec3(7.,5.,0.)/16.,s=vec3(9.,16.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,5.,14.)/16.,s=vec3(9.,16.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,6.,2.)/16.,s=vec3(9.,9.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,12.,2.)/16.,s=vec3(9.,15.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,9.,6.)/16.,s=vec3(9.,12.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(abs(y-203.5)<1.)
         {
           r=vec3(7.,5.,0.)/16.,s=vec3(9.,16.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,5.,14.)/16.,s=vec3(9.,16.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           if(y==204.)
             {
               r=vec3(9.,12.,0.)/16.,s=vec3(13.,15.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,12.,14.)/16.,s=vec3(13.,15.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,6.,0.)/16.,s=vec3(13.,9.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,6.,14.)/16.,s=vec3(13.,9.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(13.,6.,0.)/16.,s=vec3(15.,15.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(13.,6.,14.)/16.,s=vec3(15.,15.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
           else
             {
               r=vec3(3.,12.,0.)/16.,s=vec3(7.,15.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,12.,14.)/16.,s=vec3(7.,15.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,6.,0.)/16.,s=vec3(7.,9.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,6.,14.)/16.,s=vec3(7.,9.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(1.,6.,0.)/16.,s=vec3(3.,15.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(1.,6.,14.)/16.,s=vec3(3.,15.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
         }
       else if(y==205)
         {
           r=vec3(7.,2.,0.)/16.,s=vec3(9.,13.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,2.,14.)/16.,s=vec3(9.,13.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,3.,2.)/16.,s=vec3(9.,6.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,9.,2.)/16.,s=vec3(9.,12.,14.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,6.,6.)/16.,s=vec3(9.,9.,10.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           r=vec3(7.,2.,0.)/16.,s=vec3(9.,13.,2.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           r=vec3(7.,2.,14.)/16.,s=vec3(9.,13.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           if(y==207.)
             {
               r=vec3(9.,9.,0.)/16.,s=vec3(13.,12.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,9.,14.)/16.,s=vec3(13.,12.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,3.,0.)/16.,s=vec3(13.,6.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(9.,3.,14.)/16.,s=vec3(13.,6.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(13.,3.,0.)/16.,s=vec3(15.,12.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(13.,3.,14.)/16.,s=vec3(15.,12.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
           else
             {
               r=vec3(3.,9.,0.)/16.,s=vec3(7.,12.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,9.,14.)/16.,s=vec3(7.,12.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,3.,0.)/16.,s=vec3(7.,6.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(3.,3.,14.)/16.,s=vec3(7.,6.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(1.,3.,0.)/16.,s=vec3(3.,12.,2.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               r=vec3(1.,3.,14.)/16.,s=vec3(3.,12.,16.)/16.;
               m=d(v+r,v+s,f,x,t);
               i=i||m;
               return i;
             }
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
       return i;
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
           return i;
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
           return i;
         }
       else if(y==212.)
         {
           r=vec3(7.,13.,0.)/16.,s=vec3(9.,15.,13.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==213.)
         {
           r=vec3(7.,13.,3.)/16.,s=vec3(9.,15.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==214.)
         {
           r=vec3(3.,13.,7.)/16.,s=vec3(16.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==215.)
         {
           r=vec3(0.,13.,7.)/16.,s=vec3(13.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==216.)
         {
           r=vec3(7.,13.,0.)/16.,s=vec3(9.,15.,16.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else if(y==217.)
         {
           r=vec3(0.,13.,7.)/16.,s=vec3(16.,15.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
       else
         {
           r=vec3(7.,13.,7.)/16.,s=vec3(9.,16.,9.)/16.;
           m=d(v+r,v+s,f,x,t);
           i=i||m;
           return i;
         }
     }
   else if(abs(y-222.)<4.)
     {
       float r=2.*(y-219)+1.;
       r/=16.;
       m=d(v+vec3(r,0.,1./16.),v+vec3(15.,8.,15.)/16,f,x,t);
       i=i||m;
       return i;
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
       return i;
     }
   #endif
   #endif
   return i;
 }
