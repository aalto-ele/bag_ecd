from bag.design import Module
from bag.math import float_to_si_string

class MOMCapModuleBase(Module):
    """The base design class for a real resistor parametrized by width and length.

    Parameters
    ----------
    database : ModuleDB
        the design database object.
    yaml_file : str
        the netlist information file name.
    **kwargs :
        additional arguments
    """

    def __init__(self, database, yaml_file, **kwargs):
        Module.__init__(self, database, yaml_file, **kwargs)

    @classmethod
    def get_params_info(cls):
        # type: () -> Dict[str, str]
        return dict(
            w='cap finger width, in meters.',
            l='cap finger length, in meters.',
            nf='number of cap fingers (int).',
            sp='spacing between fingers, in meters.',
            stm='metal start layer',
            spm='metal stop layer',
            )

    def design(self, w=1e-6, l=1e-6, nf=10, sp=1e-6, stm=1, spm=6):
        pass

    def get_schematic_parameters(self):
        # type: () -> Dict[str, str]
        w = self.params['w']
        l = self.params['l']
        nf = self.params['nf']
        sp = self.params['sp']
        stm = self.params['stm']
        spm = self.params['spm']
        wstr = w if isinstance(w, str) else float_to_si_string(w)
        lstr = l if isinstance(l, str) else float_to_si_string(l)
        nfstr = nf if isinstance(nf, str) else "%s" % int(nf)
        spstr = sp if isinstance(sp, str) else float_to_si_string(sp)
        stmstr = stm if isinstance(stm, str) else "%s" % int(stm)
        spmstr = spm if isinstance(spm, str) else "%s" % int(spm)

        return dict(w=wstr, l=lstr, nf=nfstr, sp=spstr, stm=stmstr, spm=spmstr)#, m=mstr)

    def get_cell_name_from_parameters(self):
        # type: () -> str
        return 'cap_mom_accurate'

    def is_primitive(self):
        # type: () -> bool
        return True

    def should_delete_instance(self):
        # type: () -> bool
        return self.params['w'] == 0 or self.params['l'] == 0 or self.params['nf'] == 0

