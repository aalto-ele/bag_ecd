'''
BAG ECD --- routing.py

Helper functions for instance routing in layout generators
written with the Berkeley Analog Generator (BAG) framework.

Created on 09.03.2021 by Santeri Porrasmaa, santeri.porrasmaa@aalto.fi

'''

from bag.layout.routing.base import WireArray
from bag.layout.util import BBox 

class routing_helper():
    '''
    Helper class to aggregate helper functions for routing.

    Parameters:

    grid : bag.layout.routing.RoutingGrid
        The grid used in the template

    '''
    def __init__(self, grid):
        self._grid = grid 
        self._tech_info = grid.tech_info

    def get_parallel_run_length(self, wire_lower, wire_upper, adj_wire, unit_mode=False):
        '''
        Helper function to find the parallel run length between a wire to be
        drawn and a wire adjacent to that wire. Assumes that wires are routed
        in the same direction.
        
        Parameters:
        ----------
        wire_lower: Union[int, float]
            Lower coordinate of wire to be drawn
        wire_upper : Union[int, float]
            Upper coordinate of wire to be drawn
        adj_wire : WireArray
            WireArray adjacent to the one being drawn
        unit_mode : boolean
            If true, upper and lower coordinates were given in resolution
            units
        
        Returns:
        --------
        par_len : Union[int, float]
            Parallel run length of the two wires
        '''
        grid = self._grid
        res = grid.resolution
        if not isinstance(adj_wire, WireArray):
            raise Exception('Invalid type %s for argument adj_wires!' % type(adj_wires))
        if not unit_mode:
            wire_upper = int(wire_upper/res)
            wire_lower = int(wire_lower/res)
        if wire_upper < wire_lower:
            raise Exception('Non-physical wire end points given (e.g. upper < lower)!')
        par_len = min(wire_upper, adj_wire.upper_unit) - max(wire_lower, adj_wire.lower_unit) 
        if par_len < 0: # If the run length is negative, the y-projections do not overlap
            par_len = 0
        return par_len if unit_mode else par_len * res

    def get_parallel_run_length_primitive(self, wire_lower, wire_upper, adj_box, direction, unit_mode=False):
        '''
        Helper function to find the parallel run length between a wire to be
        drawn and a primitive wire adjacent to that wire.

        Parameters:
        ----------
        wire_lower: Union[int, float]
            Lower coordinate of wire to be drawn
        wire_upper : Union[int, float]
            Upper coordinate of wire to be drawn
        adj_box : BBox 
            Bounding box of the primitive wire 
        direction : str
            Routing direction, either 'x' or 'y'.
        unit_mode : boolean
            If true, upper and lower coordinates were given in resolution
            units
        Returns:
        --------
        par_len : Union[int, float]
            Parallel run length of the two wires
        '''
        grid = self._grid
        res = grid.resolution
        valid_dirs = set(['x', 'y'])
        if not isinstance(adj_box, BBox):
            raise Exception('Invalid type %s for argument adj_box!' % type(adj_box))
        if direction not in valid_dirs:
            raise Exception('Direction must be either x or y!')
        if wire_upper < wire_lower:
            raise Exception('Non-physical wire end points given (e.g. upper < lower)!')
        if not unit_mode:
            wire_upper = int(wire_upper/res)
            wire_lower = int(wire_lower/res)
        if direction == 'x':
            par_len = min(wire_upper, adj_box.right_unit) - max(wire_lower, adj_box.left_unit) 
        else:
            par_len = min(wire_upper, adj_box.top_unit) - max(wire_lower, adj_box.bottom_unit) 
        if par_len < 0: # If the run length is negative, the y-projections do not overlap
            par_len = 0
        return par_len if unit_mode else par_len * res
         
    def get_min_space_parallel(self, layer_id, width, length, same_color=False, unit_mode=False):
        '''
        Helper function to find minimum spacing between two parallel wires

        Parameters:
        ----------
        layer_id : int
            routing grid layer id
        width : Union[int, float]
            maximum width of two parallel wires 
        length : Union[int, float]
            parallel run length of two parallel wires 
        same_color : boolean 
            True to use same-color spacing 
        unit_mode : boolean
            If true, width and length were given in resolution
            units

        Returns:
        --------
        sp : Union[int, float]
            minimum required spacing between two parallel wires 
        '''

        tech_info = self._tech_info
        parfunc = getattr(tech_info, 'get_parallel_space', None)
        if not callable(parfunc):
            raise Exception('Cannot find parallel spacing! Function get_parallel_space not in tech.def!')
        lay_name = tech_info.get_layer_name(layer_id)
        if isinstance(lay_name, tuple):
            lay_name = lay_name[0]
        lay_type = tech_info.get_layer_type(lay_name)
        return tech_info.get_parallel_space(lay_type, width, length, same_color, unit_mode)
