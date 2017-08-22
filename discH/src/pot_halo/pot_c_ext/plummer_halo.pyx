#cython: language_level=3, boundscheck=False, cdivision=True, wraparound=False
from libc.math cimport sqrt, log, asin, pow
from discH.src.pot_halo.pot_c_ext.general_halo cimport xi, m_calc, integrand_core, potential_core
from scipy.integrate import quad
from scipy._lib._ccallback import LowLevelCallable
import numpy as np
cimport numpy as np

cdef double PI=3.14159265358979323846


cdef double psi_plummer(double d0, double rc, double m) nogil:


    cdef:
        double costn=0.66666666666666667
        double x=m/rc
        double costm=pow(1+x*x, 1.5)


    return d0*costn*(1-1/costm)

cdef double integrand_plummer(int n, double *data) nogil:


    cdef:
        double m = data[0]

    if m==0.: return 0 #Xi diverge to infinity when m tends to 0, but the integrand tends to 0

    cdef:
        double R = data[1]
        double Z = data[2]
        double mcut = data[3]
        double d0 = data[4]
        double rc = data[5]
        double e = data[6]
        double psi, result #, num, den

    if (m<=mcut): psi=psi_plummer(d0,rc,m)
    else: psi=psi_plummer(d0,rc,mcut)

    result=integrand_core(m, R, Z, e, psi)
    #num=xi(m,R,Z,e)*(xi(m,R,Z,e)-e*e)*sqrt(xi(m,R,Z,e)-e*e)*m*psi
    #den=((xi(m,R,Z,e)-e*e)*(xi(m,R,Z,e)-e*e)*R*R)+(xi(m,R,Z,e)*xi(m,R,Z,e)*Z*Z)

    return result


cdef double  _potential_plummer(double R, double Z, double mcut, double d0, double rc, double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double intpot
        double result

    m0=m_calc(R,Z,e)

    #Integ
    import discH.src.pot_halo.pot_c_ext.plummer_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_plummer')

    intpot=quad(fintegrand,0.,m0,args=(R,Z,mcut,d0,rc,e),epsabs=toll,epsrel=toll)[0]


    psi=psi_plummer(d0,rc,mcut)

    result=potential_core(e, intpot, psi)

    return result

cdef double[:,:]  _potential_plummer_array(double[:] R, double[:] Z, int nlen, double mcut, double d0, double rc, double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double[:,:] ret=np.empty((nlen,3), dtype=np.dtype("d"))
        double intpot
        int i



    #Integ
    import discH.src.pot_halo.pot_c_ext.plummer_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_plummer')


    for  i in range(nlen):


        ret[i,0]=R[i]
        ret[i,1]=Z[i]

        m0=m_calc(R[i],Z[i],e)

        intpot=quad(fintegrand,0.,m0,args=(R[i],Z[i],mcut,d0,rc,e),epsabs=toll,epsrel=toll)[0]

        psi=psi_plummer(d0,rc,mcut)

        ret[i,2]=potential_core(e, intpot, psi)


        #if (e<=0.0001):
        #    ret[i,2] = -cost*(psi-intpot)
        #else:
        #    ret[i,2] = -cost*(sqrt(1-e*e)/e)*(psi*asin(e)-e*intpot)

    return ret


cdef double[:,:]  _potential_plummer_grid(double[:] R, double[:] Z, int nlenR, int nlenZ, double mcut, double d0, double rc, double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double[:,:] ret=np.empty((nlenR*nlenZ,3), dtype=np.dtype("d"))
        double intpot
        int i, j, c



    #Integ
    import discH.src.pot_halo.pot_c_ext.plummer_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_plummer')

    c=0
    for  i in range(nlenR):
        for j in range(nlenZ):

            ret[c,0]=R[i]
            ret[c,1]=Z[j]

            m0=m_calc(R[i],Z[j],e)

            intpot=quad(fintegrand,0.,m0,args=(R[i],Z[j],mcut,d0,rc,e),epsabs=toll,epsrel=toll)[0]

            psi=psi_plummer(d0,rc,mcut)

            ret[c,2]=potential_core(e, intpot, psi)
            #if (e<=0.0001):
            #    ret[c,2] = -cost*(psi-intpot)
            #else:
            #    ret[c,2] = -cost*(sqrt(1-e*e)/e)*(psi*asin(e)-e*intpot)

            c+=1

    return ret

cpdef potential_plummer(R, Z, d0, rc, e, mcut, toll=1e-4, grid=False):

    if isinstance(R, float) or isinstance(R, int):
        if isinstance(Z, float) or isinstance(Z, int):
            return np.array(_potential_plummer(R=R,Z=Z,mcut=mcut,d0=d0,rc=rc,e=e,toll=toll))
        else:
            raise ValueError('R and Z have different dimension')
    else:
        if grid:
            R=np.array(R,dtype=np.dtype("d"))
            Z=np.array(Z,dtype=np.dtype("d"))
            return np.array(_potential_plummer_grid( R=R, Z=Z, nlenR=len(R), nlenZ=len(Z), mcut=mcut, d0=d0, rc=rc, e=e, toll=toll))
        elif len(R)==len(Z):
            nlen=len(R)
            R=np.array(R,dtype=np.dtype("d"))
            Z=np.array(Z,dtype=np.dtype("d"))
            return np.array(_potential_plummer_array( R=R, Z=Z, nlen=len(R), mcut=mcut, d0=d0, rc=rc, e=e, toll=toll))
        else:
            raise ValueError('R and Z have different dimension')