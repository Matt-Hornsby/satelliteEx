defmodule Satrec do
  defstruct satnum: nil,
            epochyr: nil,
            epochdays: nil,
            ndot: nil,
            nddot: nil,
            bstar: nil,
            inclo: nil,
            nodeo: nil,
            ecco: nil,
            argpo: nil,
            mo: nil,
            no: nil,
            a: nil,
            alta: nil,
            altp: nil,
            jdsatepoch: nil,
            #  ----------- set all near earth variables to zero ------------
            isimp: 0, method: 'n', aycof: 0.0,
            con41: 0.0, cc1: 0.0, cc4: 0.0,
            cc5: 0.0, d2: 0.0, d3: 0.0,
            d4: 0.0, delmo: 0.0, eta: 0.0,
            argpdot: 0.0, omgcof: 0.0, sinmao: 0.0,
            t: 0.0, t2cof: 0.0, t3cof: 0.0,
            t4cof: 0.0, t5cof: 0.0, x1mth2: 0.0,
            x7thm1: 0.0, mdot: 0.0, nodedot: 0.0,
            xlcof: 0.0, xmcof: 0.0, nodecf: 0.0,
            # ----------- set all deep space variables to zero ------------
            irez: 0, d2201: 0.0, d2211: 0.0,
            d3210: 0.0, d3222: 0.0, d4410: 0.0,
            d4422: 0.0, d5220: 0.0, d5232: 0.0,
            d5421: 0.0, d5433: 0.0, dedt: 0.0,
            del1: 0.0, del2: 0.0, del3: 0.0,
            didt: 0.0, dmdt: 0.0, dnodt: 0.0,
            domdt: 0.0, e3: 0.0, ee2: 0.0,
            peo: 0.0, pgho: 0.0, pho: 0.0,
            pinco: 0.0, plo: 0.0, se2: 0.0,
            se3: 0.0, sgh2: 0.0, sgh3: 0.0,
            sgh4: 0.0, sh2: 0.0, sh3: 0.0,
            si2: 0.0, si3: 0.0, sl2: 0.0,
            sl3: 0.0, sl4: 0.0, gsto: 0.0,
            xfact: 0.0, xgh2: 0.0, xgh3: 0.0,
            xgh4: 0.0, xh2: 0.0, xh3: 0.0,
            xi2: 0.0, xi3: 0.0, xl2: 0.0,
            xl3: 0.0, xl4: 0.0, xlamo: 0.0,
            zmol: 0.0, zmos: 0.0, atime: 0.0,
            xli: 0.0, xni: 0.0,
            init: 'y',
            t: 0.0,
            operationmode: nil,
            error: 0
end