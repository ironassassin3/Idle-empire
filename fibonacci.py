"""
Fibonacci number generator module.
Provides functions to calculate and generate Fibonacci sequences.
"""


def fibonacci(n):
    """
    Generate the first n Fibonacci numbers.

    Args:
        n (int): Number of Fibonacci numbers to generate (must be >= 0)

    Returns:
        list: List containing the first n Fibonacci numbers

    Examples:
        >>> fibonacci(10)
        [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]

        >>> fibonacci(0)
        []

        >>> fibonacci(1)
        [0]
    """
    if n < 0:
        raise ValueError("n must be a non-negative integer")
    
    if n == 0:
        return []
    
    if n == 1:
        return [0]
    
    # Generate Fibonacci sequence iteratively
    fib_sequence = [0, 1]
    for i in range(2, n):
        fib_sequence.append(fib_sequence[i - 1] + fib_sequence[i - 2])
    
    return fib_sequence[:n]


def fibonacci_nth(n):
    """
    Get the nth Fibonacci number (0-indexed).

    Args:
        n (int): Position in the Fibonacci sequence (must be >= 0)

    Returns:
        int: The nth Fibonacci number

    Examples:
        >>> fibonacci_nth(0)
        0

        >>> fibonacci_nth(1)
        1

        >>> fibonacci_nth(10)
        55
    """
    if n < 0:
        raise ValueError("n must be a non-negative integer")
    
    if n == 0:
        return 0
    
    if n == 1:
        return 1
    
    # Iterative approach for efficiency
    prev, curr = 0, 1
    for _ in range(2, n + 1):
        prev, curr = curr, prev + curr
    
    return curr


def fibonacci_recursive(n):
    """
    Get the nth Fibonacci number using recursive approach.

    Args:
        n (int): Position in the Fibonacci sequence (must be >= 0)

    Returns:
        int: The nth Fibonacci number

    Note: This is less efficient for large n due to repeated calculations.
    Use fibonacci_nth() for better performance.

    Examples:
        >>> fibonacci_recursive(10)
        55
    """
    if n < 0:
        raise ValueError("n must be a non-negative integer")
    
    if n == 0 or n == 1:
        return n
    
    return fibonacci_recursive(n - 1) + fibonacci_recursive(n - 2)


if __name__ == "__main__":
    # Test the functions
    print("First 15 Fibonacci numbers:")
    print(fibonacci(15))
    
    print("\nSpecific nth values:")
    for i in range(10):
        print(f"F({i}) = {fibonacci_nth(i)}")