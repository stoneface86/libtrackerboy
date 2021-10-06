/*
 * This program tests the PatternRun class.
 *
 */

#include "trackerboy/data/Module.hpp"
#include "trackerboy/compiler/PatternRun.hpp"

#include <fstream>
#include <iostream>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <numeric>

constexpr int EXIT_BAD_ARGS = 1;
constexpr int EXIT_FILE = 2;
constexpr int EXIT_BAD_MODULE = 3;


int main(int argc, const char *argv[]) {

    // argument parsing, 1 required 1 optional
    int songIndex;
    switch (argc) {
        case 2:
            songIndex = 0;
            break;
        case 3: {
            unsigned long parsed = std::strtoul(argv[2], nullptr, 10);
            if (parsed > 255) {
                std::cerr << "invalid song index" << std::endl;
                return EXIT_BAD_ARGS;
            }
            songIndex = (int)parsed;
            break;
        }
        default:
            std::cerr << "usage: " << argv[0] << " <module> [songIndex]" << std::endl;
            return EXIT_BAD_ARGS;

    }

    // read in the module
    trackerboy::Module mod;
    std::ifstream stream(argv[1], std::ios::in | std::ios::binary);
    if (!stream.good()) {
        // bad file
        std::cerr << "file error: " << strerror(errno)  << std::endl;
        return EXIT_FILE;
    }

    // deserialize module data
    auto err = mod.deserialize(stream);
    if (err != trackerboy::FormatError::none) {
        // bad module
        std::cerr << "Module is invalid\n";
        return EXIT_BAD_MODULE;
    }

    // make sure the chosen song to run exists
    if (songIndex >= mod.songs().size()) {
        std::cerr << "Module does not have song #" << songIndex << std::endl;
        return EXIT_BAD_ARGS;
    }

    // get the song
    trackerboy::Song const* song = mod.songs().get(songIndex);

    std::cout << "\nRun information for song #" << songIndex << " - '" << song->name() << "'\n";
    std::cout << "Pattern size: " << song->patterns().length() << " rows.\n";

    // do the run
    trackerboy::PatternRun run(*song);

    // and print the results

    auto &visits = run.visits();

    std::cout << std::endl;
    std::cout << std::left;
    for (size_t index = 0; index < visits.size(); ++index) {
        auto const& v = visits[index];
        std::cout << "Visit #" << std::setw(3) << index
                  << ": Pattern #" << std::setw(3) << v.pattern
                  << " Rows: " << std::setw(3) << v.rowCount
                  << "\n";
    }
    std::cout << std::endl;

    auto rowAccumulator = [](int sum, trackerboy::PatternRun::Visit const& b) {
        return sum + b.rowCount;
    };

    if (run.halts()) {
        int runCount = std::accumulate(visits.begin(), visits.end(), 0, rowAccumulator);
        std::cout << "The song will halt after playing " << runCount << " rows.\n";
    } else {
        auto loopIndex = run.loopIndex();
        std::cout << "The song will loop at visit #" << loopIndex;
        std::cout << " (Pattern #" << visits[loopIndex].pattern << ").\n";

        auto firstRunPlayCount = std::accumulate(visits.begin(), visits.end(), 0, rowAccumulator);
        auto loopRunPlayCount = firstRunPlayCount - std::accumulate(visits.begin(), visits.begin() + loopIndex, 0, rowAccumulator);

        if (firstRunPlayCount == loopRunPlayCount) {
            std::cout << "Each run will play " << firstRunPlayCount << " rows.\n";
        } else {
            std::cout << "The first run will play " << firstRunPlayCount
                      << " rows. (following runs will play " << loopRunPlayCount
                      << " rows).\n";
        }
    }

    std::cout << std::endl;

    return 0;
}
