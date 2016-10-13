from .padic_valuation import pAdicValuation
from .gauss_valuation import GaussValuation
import discrete_valuation, padic_valuation

# =================
# MONKEY PATCH SAGE
# =================
import sys
import sage
# Register all modules within sage (to make doctests pass)
sys.modules['sage.rings.padics.discrete_valuation'] = discrete_valuation
sage.rings.padics.discrete_valuation = discrete_valuation
sys.modules['sage.rings.padics.padic_valuation'] = padic_valuation
sage.rings.padics.padic_valuation = padic_valuation

# fix pAdicValuation pickling
from sage.structure.factory import register_factory_unpickle
register_factory_unpickle("pAdicValuation", pAdicValuation)
