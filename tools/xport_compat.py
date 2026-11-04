"""Constructor-only compatibility for xport 3.6.1 on pandas 3.

No XPORT parsing or encoding is changed. xport's old positional fastpath is
discarded; pandas 3 removed it. copy=False now means copy=None to retain the
old 'copy if required' behavior. This adapter is development-only.
"""
import pandas as pd

_series_init = pd.Series.__init__

def _init(self, data=None, index=None, dtype=None, name=None, copy=None,
          fastpath=False, **kwargs):
    _series_init(self, data=data, index=index, dtype=dtype, name=name,
                 copy=None if copy is False else copy, **kwargs)

pd.Series.__init__ = _init
import xport  # noqa: E402
import xport.v56  # noqa: E402
