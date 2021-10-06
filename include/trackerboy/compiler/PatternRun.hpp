
#pragma once

#include "trackerboy/data/Song.hpp"

#include <vector>

namespace trackerboy {

/*!
 * \brief Runtime information for a song.
 *
 * The PatternRun class determines how a song will play out. It determines:
 *  - Whether a song will halt or loop forever
 *  - The order in which patterns are "visited", and the count of rows for each visited pattern
 *  - The loop index (if a song does not halt), or the pattern in the
 *    visit order that the song loops back to.
 *
 * This class is used for compilation purposes, so that non-reachable pattern
 * data can be ignored during the compilation process. Only what the PatternRun "visits"
 * will be compiled.
 */
class PatternRun {

public:

    /*!
     * \brief POD struct for a pattern visit.
     *
     * This POD contains two members, the pattern id that was visited, and the
     * number of rows that were visited.
     */
    struct Visit {
        int pattern;    //!< the pattern id that was visited
        int rowCount;   //!< the number of rows in the pattern visited

    };

    /*!
     * \brief Constructs a pattern run for the given \a song
     * \param song the song to run
     *
     * Calculates the visit order of the \a song, along with pattern counts
     * and the loop index. See visits() documentation for details on how
     * the visit order is calculated.
     */
    PatternRun(Song const& song);

    /*!
     * \brief Determines if the song halts
     * \return true if the song halts during playback, false otherwise
     *
     * If a song does not halt, it will loop to the pattern in the visit order
     * at the loopIndex().
     */
    bool halts() const noexcept;

    /*!
     * \brief The loop point of a non-halting run.
     * \return the index of the pattern in the visit order the song loops to
     *
     * If halts() is true, the result of this function can be discarded.
     */
    int loopIndex() const noexcept;

    /*!
     * \brief Gets the order in which patterns are visited
     * \return A reference to a vector of visits
     *
     * The visit order is the order in which patterns are visited when playing
     * a song. For songs with no pattern jumps, the order just visits every
     * pattern in the song's order. For example, a song with 4 patterns and no
     * jumps will have a visit order of:
     *
     *     { 0, 1, 2, 3 } // song will loop at index 0
     *
     * Any pattern ids not in the visit order are never played out, and
     * can be removed/ignored during pattern compilation.
     *
     * If the song has pattern jumps, then the visit order will jump around.
     * For example, consider a song with 3 patterns with the following jumps:
     *  - pattern #0 -> pattern #2
     *  - pattern #2 -> pattern #1
     * Then the song will have a visit order of:
     *
     *      { 0, 2, 1 } // song will loop at index 1 (pattern #2)
     *
     * In some cases a pattern jump may result in a pattern never getting
     * played. Consider a song like the first example, however, there is a
     * jump from #1 to #3 (skips #2). In this example, the visit order is:
     *
     *     { 0, 1, 3 }
     *
     * Note that #2 is not present in the visit order. Pattern #2 is "unreachable"
     * and can be ignored during the compilation process. While pattern #2's data
     * will remain in the module, its data will not be compiled when exporting to
     * assembly.
     *
     * Note that the patterns are unique in the order, or in other terms, are
     * only visited once.
     *
     */
    std::vector<Visit> const& visits() const noexcept;


private:

    bool mHalts;
    int mLoopIndex;
    std::vector<Visit> mVisits;




};


}
