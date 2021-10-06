
#include "trackerboy/compiler/PatternRun.hpp"
#include "trackerboy/data/Pattern.hpp"

#include <algorithm>

namespace trackerboy {


PatternRun::PatternRun(Song const& song) :
    mHalts(false),
    mLoopIndex(0),
    mVisits()
{
    auto const& order = song.order();
    auto const& map = song.patterns();


    struct VisitThunk {
        int rows;
        Effect lastEffect;
        bool halted;
    };

    auto visitTrack = [](Track const* track, VisitThunk &thunk) {
        if (track == nullptr) {
            // if track was nullptr, that means it doesn't exist
            // and tracks that don't exist have equalivent behavior to an empty track
            // so stop here, leaving the thunk unchanged
            return;
        }

        int rows = 0;
        auto iter = track->begin();
        auto end = iter + thunk.rows;
        for (; iter != end; ++iter) {
            ++rows;
            // check for effects Bxx, C00 or D00
            for (int i = 0; i != TrackRow::MAX_EFFECTS; ++i) {
                auto effect = iter->effects[i];
                switch (effect.type) {
                    case EffectType::patternHalt:
                        thunk.halted = true;
                        [[fallthrough]];
                    case EffectType::patternGoto:
                    case EffectType::patternSkip:
                        thunk.lastEffect = effect;
                        thunk.rows = rows;
                        return;
                    default:
                        break;

                }
            }
        }


    };


    for (int orderCounter = 0; ;) {

        auto pattern = order[orderCounter];

        // visit the pattern by visiting all tracks in the pattern
        VisitThunk thunk { map.length(), {}, false};
        visitTrack(map.getTrack(ChType::ch1, pattern[0]), thunk);
        visitTrack(map.getTrack(ChType::ch2, pattern[1]), thunk);
        visitTrack(map.getTrack(ChType::ch3, pattern[2]), thunk);
        visitTrack(map.getTrack(ChType::ch4, pattern[3]), thunk);

        // add the results of the visit
        mVisits.push_back({orderCounter, thunk.rows});

        if (thunk.halted) {
            // we done
            mHalts = true;
            break;
        }

        // determine the next pattern to visit
        int nextPattern;
        if (thunk.lastEffect.type == EffectType::patternGoto) {
            // pattern jump
            nextPattern = std::min((int)thunk.lastEffect.param, order.size() - 1);

        } else {
            // go to next pattern in order
            nextPattern = orderCounter + 1;
            if (nextPattern == order.size()) {
                // end of order, we done
                mLoopIndex = 0;
                break;
            }
        }

        // check if we have already visited the next pattern
        auto found = std::find_if(mVisits.begin(), mVisits.end(),
            [nextPattern](Visit const& visit) {
                return visit.pattern == nextPattern;
            });
        if (found == mVisits.end()) {
            // continue with this pattern
            orderCounter = nextPattern;
        } else {
            // already visited this pattern, we done
            mLoopIndex = found - mVisits.begin();
            break;
        }


    }


}

bool PatternRun::halts() const noexcept {
    return mHalts;
}

int PatternRun::loopIndex() const noexcept {
    return mLoopIndex;
}

std::vector<PatternRun::Visit> const& PatternRun::visits() const noexcept {
    return mVisits;
}

}
