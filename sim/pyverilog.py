"""@package pyverilog
This module contains classes that are used to simulate System Verilog-equivalent
objects in Python. The classes are used to simulate the behavior of System Verilog
modules, wires, and other objects. Abstract classes help structure the classes 
that inherit from them, such that items like modules and wires can be used in a 
consistent manner.
"""

from abc import ABC, abstractmethod
from random import getrandbits


class Wire(ABC):
    """A class that unifies signals that should be connected to a module."""

    ## @brief Tracks all the names of the wires created.
    _names = set()

    def __init__(self, width: int, name: str = None):
        """
        Instantiates a Wire such that all consumers of a wire are synced.

        Args:
            width (int): The width of the wire.
            name (str): The name of the wire.

        Returns:
            None: Nothing.

        Raises:
            ValueError: The wire name is in use.

        Preconditions:
            - The width is a positive integer.
            - The name is a string not in Wire._names.

        Postconditions:
            - A wire is created with the specified width and name.
            - Wire._names is updated with the new wire name.
        """
        self.width = width
        self.value = None
        if name is None:
            name = getrandbits(64)
            while name not in Wire._names:
                name = getrandbits(64)
        else:
            if name in Wire._names:
                raise ValueError(f"Name {name} is already in use")

        Wire._names.add(name)
        self.name = name

    @property
    def value(self) -> int:
        """The value of the wire."""
        return self._value

    @value.setter
    def value(self, value: int) -> None:
        """Sets the value of the wire."""
        if value < 0 or value >= 2**self.width:
            raise ValueError(f"Value {value} is out of range for width {self.width}")
        self._value = value

    @property
    def bin(self) -> str:
        """The binary representation of the wire."""
        return bin(self.value)

    @property
    def hex(self) -> str:
        """The hexadecimal representation of the wire."""
        return hex(self.value)


class Buffer(Wire):
    """A class that represents a buffer wire."""

    def __init__(self, width: int, line: Wire, clock: Wire, name: str = None):
        """
        Instantiates a Buffer wire such that all consumers of a wire are synced.

        Args:
            width (int): The width of the wire.
            line (Wire): The wire to the buffer.
            clock (Wire): The clock signal for the buffer.
            name (str): The name of the wire.

        Returns:
            None: Nothing.

        Preconditions:
            - The width is a positive integer.
            - The name is a string not in Wire._names.
            - The input is a Wire.
            - bool(Clock) is True when the clock is high.

        Postconditions:
            - A buffer is created with the specified width, name, input, and clock.
            - Wire._names is updated with the new wire name.
        """
        super().__init__(width, name)
        self._value = None
        self._input = line
        self._clock = clock

    @property
    def value(self) -> int:
        return self._value

    async def tick(self) -> None:
        """
        Updates the value of the buffer wire.

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


class Module(ABC):
    """A class that structures how to simulate a SV module."""

    def __init__(
        self, inputs: dict[str, Wire], outputs: dict[str, Wire], name: str = None
    ):
        """
        Instantiates a Module with inputs and outputs.

        Args:
            inputs (dict[str, Wire]): The input wires to the module.
            outputs (dict[str, Wire]): The output wires to the module.
            name (str): The name of the module.

        Returns:
            None: Nothing.

        Preconditions:
            - The inputs and outputs are dictionaries of strings to Wires.
            - The name is a string.

        Postconditions:
            - The module is created with the specified inputs, outputs, and name.
        """
        self._inputs = inputs
        self._outputs = outputs
        self.name = name

    @abstractmethod
    async def tick(self) -> None:
        """
        Updates the values of the output wires.

        Args:
            None: Nothing.

        Returns:
            None: Nothing.

        Preconditions:
            - The values of the input wires are updated.

        Postconditions:
            - The values of the output wires are updated.
        """
        raise NotImplementedError("tick() must be implemented in a subclass")

    @property
    def inputs(self) -> dict[str, Wire]:
        """The input wires to the module."""
        return self._inputs

    @property
    def outputs(self) -> dict[str, Wire]:
        """The output wires to the module."""
        return self._outputs


class Sequential(Module):
    """A class that represents a sequential module."""

    def __init__(
        self, inputs: dict[str, Wire], outputs: dict[str, Wire], name: str = None
    ):
        """
        Instantiates a Sequential module with inputs and outputs.

        Args:
            inputs (dict[str, Wire]): The input wires to the module.
            outputs (dict[str, Wire]): The output wires to the module.
            name (str): The name of the module.

        Returns:
            None: Nothing.

        Preconditions:
            - The inputs and outputs are dictionaries of strings to Wires.
            - The name is a string.

        Postconditions:
            - The module is created with the specified inputs, outputs, and name.
        """
        super().__init__(inputs, outputs, name)
        self._clock = inputs["clock"]

    @abstractmethod
    async def tick(self) -> None:
        """
        Updates the values of the output wires.

        Args:
            None: Nothing.

        Returns:
            None: Nothing.

        Preconditions:
            - The clock is high.

        Postconditions:
            - The values of the output wires are updated.
        """
        raise NotImplementedError("tick() must be implemented in a subclass")


class Combinational(Module):
    """A class that represents a combinational module."""

    def __init__(
        self, inputs: dict[str, Wire], outputs: dict[str, Wire], name: str = None
    ):
        """
        Instantiates a Combinational module with inputs and outputs.

        Args:
            inputs (dict[str, Wire]): The input wires to the module.
            outputs (dict[str, Wire]): The output wires to the module.
            name (str): The name of the module.

        Returns:
            None: Nothing.

        Preconditions:
            - The inputs and outputs are dictionaries of strings to Wires.
            - The name is a string.

        Postconditions:
            - The module is created with the specified inputs, outputs, and name.
        """
        # Checks none of the output wires are buffers.
        for output in outputs.values():
            if isinstance(output, Buffer):
                raise ValueError("Output wires cannot be buffers")
        super().__init__(inputs, outputs, name)

    @abstractmethod
    async def tick(self) -> None:
        """
        Updates the values of the output wires.

        Args:
            None: Nothing.

        Returns:
            None: Nothing.

        Preconditions:
            - The values of the input wires are updated.

        Postconditions:
            - The values of the output wires are updated.
        """
        raise NotImplementedError("tick() must be implemented in a subclass")
