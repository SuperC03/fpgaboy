"""A working PPU simulator in the form of a Python class."""
import pyverilog

class PictureProcessingUnit(pyverilog.Module):
    """A class that simulates a PPU."""
    
    def __init__(
            self, inputs: dict[str, pyverilog.Wire], 
            outputs: dict[str, pyverilog.Wire], name: str = None
        ):
        """
        Instantiates a PPU with inputs and outputs.
        
        Args:
            inputs (dict[str, pyverilog.Wire]): The input wires to the PPU.
            outputs (dict[str, pyverilog.Wire]): The output wires to the PPU.
            name (str): The name of the PPU.
        
        Returns:
            None: Nothing.
        
        Preconditions:
            - The inputs and outputs are dictionaries of strings to Wires.
            - The name is a string.
        
        Postconditions:
            - The PPU is created with the specified inputs, outputs, and name.
        """
        super().__init__(inputs, outputs, name)
        self._clock = inputs["clock"]
        self._input = inputs["input"]
        self._value = 0
    
    def tick(self) -> None:
        """
        Updates the value of the buffer.
        
        Args:
            None: Nothing.
        
        Returns:
            None: Nothing.
        
        Preconditions:
            - The clock is high.
        
        Postconditions:
            - The value of the buffer is updated to the value of the input.
        """
        if self._clock.value:
            self._value = self._input.value
        
