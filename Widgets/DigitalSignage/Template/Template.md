# LiquidJS Template Concept

* Once the CustomWidget dataset is returned, check and see if the dataset contains more than three events.
* If it has three or less, show all.
* If it has more than three, HIDE ALL with CSS (display: none;)
    * Unhide the first three (pre-sorted by the stored procedure
    * Wait the defined amount of time (seconds)
    * Hide those three and display the next three
    * Repeat until all are shown