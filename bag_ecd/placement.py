'''
BAG ECD --- placement.py

Helper functions for instance placement in layout generators
written with the Berkeley Analog Generator (BAG) framework.

Created on 09.03.2021 by Santeri Porrasmaa, santeri.porrasmaa@aalto.fi

'''

import numpy as np

class placement_helper():
    '''
    Helper class to aggregate helper functions for placement.

    Parameters:

    grid : bag.layout.routing.RoutingGrid
        The grid used in the template

    '''
    def __init__(self, grid):
        self._grid = grid 

    def get_edge_coord(self, instance_iter, excl_list=[],unit_mode=False):
        '''
        Helper function to find the coordinates of the edge of given direction.
        Based on finding the largest (or smallest) bound from template instance 
        bounding boxes.
        
        Parameters:
        -------
        instance_iter : Iter[bag.layout.objects.Insntance]
            Iterator of instances in the current template
            (e.g. self.instance_iter() in layout class)
        excl_list : List[bag.layout.objects.Instance]
            List of instances to be excluded from edge coordinate
            calculation.
        unit_mode : boolean
            Return edge coordinate(s) in resolution units if true.
            Else, return in layout units.

        Returns:
        -------
        edges: Tuple[int, int, int, int]
            Tuple of left, bottom, right and top edge coordinates
        ''' 
        # Check if excl_list is of correct type
        if not isinstance(excl_list, list):
            if isinstance(excl_list, Instance):
                excl_list = [excl_list]
            else:
                raise ValueError("excl_list should be a list of instances or a singular instance (bag.layout.objects.Instace) ")
        # Loop over instances, store edge coords in list 
        edges = [[] for i in range(0, 4)]
        for inst in instance_iter:
            if not inst in excl_list:
                bounds = inst.bound_box.get_bounds(unit_mode)
                for edge, coord in zip(edges, bounds):
                    edge.append(coord)
        # Return edge coords
        edges = [min(edges[0]), min(edges[1]), max(edges[2]), max(edges[3])]
        return edges 


    def coord_to_grid(self, coord, layer, mode=0, half_track=False, unit_mode=False):
        '''
        Helper function to calculate coordinates that are aligned with grid. Useful for
        placing instances with pins on specific layers.

        Parameters:
        -------
        coord : Union[float, int]
            x or y coordinate to be rounded to track multiples. 
        layer : Union[int, List[int]]
            coordinate layer ID or a list of layer IDs. If given as list,
            calculates coordinate so that coordinate is aligned to grid
            on all given layers
        mode : int
            Round coordinate up to nearest track multiple, if mode >= 0.
            Else, round down.
        half_track : boolean
            If true, use half integer tracks to calculate coordinate 
        unit_mode : boolean
            If true, coordinate was given (and is returned) in resolution units.
            Else, coordinate was given (and is returned) in layout units.

        Returns:
        -------
            ret : int
            coordinate aligned with routing grid on the given layer
        '''
        grid = self._grid
        res = grid.resolution
        if not isinstance(layer, list):
            direction = grid.get_direction(layer)
            if not unit_mode:
                coord = round(coord / res)
            if direction == 'x':
                pitch = grid.get_size_pitch(layer,unit_mode=True)[1]
                pitch = pitch // 2 if half_track else pitch
                if coord % pitch != 0:
                    ret= coord - (coord % pitch) if mode < 0 else coord + (pitch - (coord % pitch))
                    return ret*res if not unit_mode else ret
                else:
                    return coord*res if not unit_mode else coord
            else:
                pitch = grid.get_size_pitch(layer,unit_mode=True)[0]
                pitch = pitch // 2 if half_track else pitch
                if coord % pitch != 0:
                    ret = coord - (coord % pitch) if mode < 0 else coord + (pitch - (coord % pitch))
                    return ret*res if not unit_mode else ret
                else:
                    return coord*res if not unit_mode else coord
        else:
            # Check given layers are oriented in the same direction
            dirs = [grid.get_direction(lay) for lay in layer] 
            if len(set(dirs)) != 1:
                raise ValueError('All layers in the list must be of same direction!')
            pitch = [grid.get_track_pitch(lay, unit_mode=True) for lay in layer]
            pitch = [p // 2 if half_track==True else p for p in pitch] 
            pitch = np.lcm.reduce(pitch)
            if not unit_mode:
                coord = round(coord / res)
            if coord % pitch != 0:
                ret = coord - (coord % pitch) if mode < 0 else coord+(pitch-(coord%pitch))
                return ret if unit_mode else ret*res
            else:
                return coord if unit_mode else coord*res

        
    def get_child_instance(self, instance, inst_name):
        """
            Find child instance from the template hierarcy using
            DFS recursion.
            
            Parameters:
            -------
            instance : bag.layout.objects.Instance
                Instance that defines the template hierarchy (e.g. instance
                to be found is the child instance of this instance)
            inst_name: String
                Name of the instance to be found. Assumes instance name is unique
                in the hierarcy.

            Returns:
            -------
            ret: Union[bag.layout.objects.Instance, None]
                Return the found instance or None if instance wasn't
                found.

        """
        for inst in instance.master.instance_iter(): 
            if inst._inst_name == None:
                return None
            elif inst._inst_name == inst_name: # Instance was found, return it
                return inst
            else: # Go through hierarchy, depth first
                ret = self.get_child_instance(inst, inst_name)
                if ret:
                    return ret
                else:
                    continue
        return None
